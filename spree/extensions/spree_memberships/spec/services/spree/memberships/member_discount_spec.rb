require 'spec_helper'

RSpec.describe Spree::Memberships::MemberDiscount do
  let(:store) { @default_store }
  let(:group) { create(:customer_group, store: store) }
  let(:customer) { create(:customer) }
  let(:order) { create(:order, store: store, customer: customer) }
  let(:tier) { create(:membership_tier_setting, customer_group: group, member_discount_percentage: 10) }
  let(:variant) { create(:variant, price: 100) }
  let(:line_item) { create(:line_item, order: order, variant: variant) }

  # The shelf price is the variant's own; the member paid ten percent less, and
  # the line records the list that priced it.
  def price_the_line(item = line_item, price: 90, list: price_list)
    item.update_columns(price: price, price_list_id: list&.id)
    item
  end

  def price_list
    tier.reload.catalog.price_list
  end

  before do
    tier # the group has to be a tier before anybody can be moved onto it
    Spree::Memberships::AssignTier.call(customer: customer, customer_group: group)
  end

  it 'reports what the member price took off a line' do
    price_the_line

    expect(described_class.call(order: order.reload).value).to eq(line_item.id => 10)
  end

  it 'reports it by the quantity bought' do
    price_the_line
    line_item.update_columns(quantity: 3)

    expect(described_class.call(order: order.reload).value).to eq(line_item.id => 30)
  end

  # The stamp the pricing walk leaves on the line is the only thing telling a
  # member price apart from a discount the seller gave.
  it 'ignores a line the tier’s list did not price' do
    price_the_line(list: nil)

    expect(described_class.call(order: order.reload).value).to be_empty
  end

  it 'ignores a line the list priced above the shelf price' do
    price_the_line(price: 120)

    expect(described_class.call(order: order.reload).value).to be_empty
  end

  it 'reports nothing for a customer holding no tier' do
    price_the_line
    group.remove_customers([customer.id])

    expect(described_class.call(order: order.reload).value).to be_empty
  end

  # A catalogue out of effect prices nobody, so there is nothing to fund.
  it 'reports nothing once the tier’s catalogue is out of effect' do
    price_the_line
    tier.reload.catalog.update!(active: false)

    expect(described_class.call(order: order.reload).value).to be_empty
  end

  it 'reports nothing when there is no shelf price to measure against' do
    price_the_line
    variant.prices.delete_all

    expect(described_class.call(order: order.reload).value).to be_empty
  end
end
