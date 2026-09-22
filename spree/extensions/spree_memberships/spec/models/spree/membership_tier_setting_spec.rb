require 'spec_helper'

RSpec.describe Spree::MembershipTierSetting, type: :model do
  let(:store) { @default_store }
  let(:group) { create(:customer_group, store: store) }
  let(:tier) { create(:membership_tier_setting, customer_group: group) }

  it 'reaches its store through the group it hangs from' do
    expect(tier.store).to eq(store)
    expect(tier.name).to eq(group.name)
  end

  # One row per group is what makes a group a tier rather than an audience.
  it 'belongs to a group once' do
    tier

    expect(build(:membership_tier_setting, customer_group: group)).not_to be_valid
  end

  it 'needs a rank, and a term of positive days when it has one' do
    expect(build(:membership_tier_setting, customer_group: group, rank: nil)).not_to be_valid

    other = create(:customer_group, store: store)
    expect(build(:membership_tier_setting, customer_group: other, validity_days: 0)).not_to be_valid
  end

  it 'orders itself the way the client reads a ladder' do
    lower = create(:membership_tier_setting, customer_group: create(:customer_group, store: store), rank: 1)
    higher = create(:membership_tier_setting, customer_group: create(:customer_group, store: store), rank: 2)

    expect(described_class.ordered.to_a).to eq([lower, higher])
    expect(described_class.for_store(store)).to contain_exactly(lower, higher)
  end

  # A tier nobody qualifies for by spending is one the operator sells or grants,
  # and a zero would say "everybody qualifies".
  it 'qualifies a customer only where it has a threshold' do
    expect(tier.qualifies?(100)).to be(true)
    expect(tier.qualifies?(99)).to be(false)

    tier.update!(threshold: nil)
    expect(tier.qualifies?(1_000)).to be(false)
  end
end
