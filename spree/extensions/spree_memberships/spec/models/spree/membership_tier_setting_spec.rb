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

  # Among live rows only: a retired settings row is history, and a fresh one for
  # the same group is saved after it is retired.
  it 'lets a group become a tier again once the old row is retired' do
    tier.destroy

    expect(build(:membership_tier_setting, customer_group: group)).to be_valid
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

  # The member price is a catalogue the tier owns and an owned list inside it;
  # the tier row holds the link and answers what the price is.
  describe 'the member price' do
    it 'stands a catalogue up and reports the percentage' do
      tier.update!(member_discount_percentage: 10)

      expect(tier.reload.catalog).to be_present
      expect(tier.member_discount_percentage).to eq(10)
    end

    it 'moves the price without standing up a second catalogue' do
      tier.update!(member_discount_percentage: 10)
      catalog = tier.catalog

      tier.update!(member_discount_percentage: 20)

      expect(tier.reload.catalog_id).to eq(catalog.id)
      expect(tier.member_discount_percentage).to eq(20)
    end

    it 'reports none while the tier grants none' do
      expect(tier.member_discount_percentage).to be_nil
    end

    it 'takes the price out of effect on zero, and reports none' do
      tier.update!(member_discount_percentage: 10)
      tier.update!(member_discount_percentage: 0)

      expect(tier.reload.member_discount_percentage).to be_nil
      expect(tier.catalog).not_to be_active
    end

    # A retired tier leaves its members the group they were in, so a catalogue
    # left in effect would outlive the promise that set it up.
    it 'stops pricing when the tier is retired' do
      tier.update!(member_discount_percentage: 10)
      catalog = tier.catalog

      tier.destroy

      expect(catalog.reload).not_to be_active
    end
  end
end
