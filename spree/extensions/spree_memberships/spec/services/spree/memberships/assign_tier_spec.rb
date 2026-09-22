require 'spec_helper'

RSpec.describe Spree::Memberships::AssignTier do
  let(:store) { @default_store }
  let(:customer) { create(:customer) }
  let(:silver) { create(:membership_tier_setting, customer_group: create(:customer_group, store: store), rank: 1).customer_group }
  let(:gold) { create(:membership_tier_setting, customer_group: create(:customer_group, store: store), rank: 2).customer_group }

  it 'puts the customer on the tier' do
    result = described_class.call(customer: customer, customer_group: gold)

    expect(result).to be_success
    expect(customer.reload.customer_groups).to include(gold)
  end

  # A customer on two tiers is priced by whichever catalogue sits lower,
  # silently — so a tier change is a move, in one transaction.
  it 'takes them off the tier they were on' do
    described_class.call(customer: customer, customer_group: silver)
    described_class.call(customer: customer, customer_group: gold)

    expect(customer.reload.customer_groups).to contain_exactly(gold)
  end

  it 'leaves a group that is not a tier alone' do
    plain = create(:customer_group, store: store)
    described_class.call(customer: customer, customer_group: silver)

    expect(described_class.call(customer: customer, customer_group: plain)).to be_failure
    expect(customer.reload.customer_groups).to contain_exactly(silver)
  end

  it 'refuses a group that does not exist' do
    expect(described_class.call(customer: customer, customer_group: nil)).to be_failure
  end
end
