require 'spec_helper'

RSpec.describe Spree::FlashSales::ApplyTicketPrice do
  let(:store) { @default_store }
  let(:flash_sale) { create(:flash_sale, store: store, pool_all: 10, title: '周末秒杀') }
  let(:slot) { create(:flash_sale_slot, flash_sale: flash_sale, pool: 10) }
  let(:product) { create(:product, store: store, price: 100) }
  let(:variant) { product.default_variant }
  let!(:item) { create(:flash_sale_item, flash_sale: flash_sale, variant: variant, sale_amount: 60, pool: 0) }
  let(:customer) { create(:customer) }
  let(:cart) { create(:cart, store: store, customer: customer) }
  let(:line_item) { create(:line_item, cart: cart, variant: variant, quantity: 2, price: 100) }
  let(:ticket) do
    Spree::FlashSales::ClaimTicket.call(customer: customer, item: item, quantity: 2, slot: slot).value
  end

  def apply
    described_class.call(ticket: ticket, line_item: line_item)
  end

  it 'writes the difference between the catalogue and the activity' do
    row = apply.value

    expect(row.kind).to eq('manual')
    # Two units, 40 off each.
    expect(row.amount).to eq(-80)
    expect(row.line_item).to eq(line_item)
    expect(row.label).to include('周末秒杀')
  end

  # The row names both rows it came from, which is what makes the discount —
  # and the refund computed from it — traceable.
  it 'names the activity and the ticket' do
    row = apply.value

    expect(row.metadata['flash_sale_id']).to eq(flash_sale.prefixed_id)
    expect(row.metadata['flash_sale_ticket_id']).to eq(ticket.prefixed_id)
  end

  # The money moves where the customer pays it: the cart's total carries the
  # manual row, so two units at 100 come to 120 rather than 200.
  it 'prices the cart down to the activity’s price' do
    apply

    # Two units at 100, less 40 each.
    expect(cart.reload.total.to_d).to eq(120)
    expect(cart.discounts.sum(&:amount).to_d).to eq(-80)
  end

  # Re-pricing the same line updates the row rather than stacking a second
  # discount on it.
  it 'writes one row, however often it is asked' do
    apply
    apply

    expect(cart.discounts.where(code: "flash_sale:#{ticket.prefixed_id}").count).to eq(1)
    expect(cart.reload.discounts.sum(&:amount).to_d).to eq(-80)
  end

  it 'writes nothing when the catalogue already charges the activity price' do
    line_item.update!(price: 60)

    expect(apply.value).to be_nil
    expect(cart.discounts.count).to eq(0)
  end

  it 'refuses an activity that does not sell this goods' do
    other = create(:flash_sale_item, flash_sale: create(:flash_sale, store: store), sale_amount: 10)

    result = described_class.call(ticket: ticket, line_item: create(:line_item, cart: cart, variant: other.variant, quantity: 1))

    expect(result).to be_failure
  end
end
