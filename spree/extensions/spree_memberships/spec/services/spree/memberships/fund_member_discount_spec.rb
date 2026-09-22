require 'spec_helper'

RSpec.describe Spree::Memberships::FundMemberDiscount do
  let(:store) { @default_store }
  let(:group) { create(:customer_group, store: store) }
  let(:customer) { create(:customer) }
  let(:order) { create(:order, store: store, customer: customer) }
  let(:tier) { create(:membership_tier_setting, customer_group: group, member_discount_percentage: 10) }
  let(:line_item) { create(:line_item, order: order, variant: create(:variant, price: 100)) }
  # A plain double: the workflow's `order` reader is defined when it runs, not
  # on the class, so an instance_double cannot verify it.
  let(:workflow) { double(order: order) }

  def price_the_line
    line_item.update_columns(price: 90, price_list_id: tier.reload.catalog.price_list.id)
  end

  before do
    tier # the group has to be a tier before anybody can be moved onto it
    Spree::Memberships::AssignTier.call(customer: customer, customer_group: group)
  end

  it 'contributes the reduction, so the ledger can credit the seller for it' do
    price_the_line

    contribution = described_class.new.call(workflow)

    expect(contribution[:discounts]).to eq(line_item.id => 10)
  end

  # What an operator reconciling the ledger reads to answer "why was this
  # seller credited".
  it 'says which promise funded it' do
    price_the_line

    metadata = described_class.new.call(workflow)[:metadata]

    expect(metadata).to include(
      'funded_by' => 'member_price',
      'membership_tier' => tier.name,
      'membership_tier_setting_id' => tier.id
    )
    expect(metadata['member_discount_percentage'].to_d).to eq(10)
  end

  it 'contributes nothing for a customer holding no tier' do
    price_the_line
    group.remove_customers([customer.id])

    expect(described_class.new.call(workflow)).to eq({})
  end

  it 'contributes nothing when the member price took nothing off the order' do
    expect(described_class.new.call(workflow)).to eq({})
  end

  it 'contributes nothing when the workflow carries no order' do
    expect(described_class.new.call(double(order: nil))).to eq({})
  end
end
