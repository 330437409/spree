require 'spec_helper'

RSpec.describe Spree::FlashSales::SettleTicketsSubscriber do
  let(:store) { @default_store }
  let(:flash_sale) { create(:flash_sale, store: store, pool_all: 10) }
  let(:slot) { create(:flash_sale_slot, flash_sale: flash_sale, pool: 10) }
  let(:variant) { create(:product, store: store, price: 100).default_variant }
  let(:item) { create(:flash_sale_item, flash_sale: flash_sale, variant: variant, sale_amount: 60, pool: 0) }
  let(:customer) { create(:customer) }
  let(:order) { create(:completed_order_with_totals, store: store, customer: customer) }
  let(:subscriber) { described_class.new }

  def claim(quantity: 1)
    Spree::FlashSales::ClaimTicket.call(customer: customer, item: item, quantity: quantity, slot: slot).value
  end

  def event_for(record)
    double('Event', payload: { 'id' => record.prefixed_id })
  end

  def price_the_order_with(ticket)
    order.discounts.create!(
      line_item: order.line_items.first, kind: 'manual', label: '秒杀活动价', amount: -10,
      metadata: { 'flash_sale_ticket_id' => ticket.prefixed_id }
    )
  end

  # The units were bought: the ticket stops holding and the pool keeps what it
  # took, because the sale is what the count was for.
  it 'settles the ticket the order was priced with' do
    ticket = claim(quantity: 2)
    price_the_order_with(ticket)

    subscriber.handle(event_for(order))

    expect(ticket.reload.status).to eq('settled')
    expect(ticket.active_key).to be_nil
    # Every scope keeps what it took — one counter answers for all of them, and
    # a settlement is not a release.
    expect(flash_sale.pools.find_by(kind: 'all').held).to eq(2)
  end

  it 'leaves a ticket the order does not name alone' do
    priced = claim(quantity: 1)
    other = create(:flash_sale_ticket, store: store, flash_sale: flash_sale, variant: variant,
                                       flash_sale_slot: slot, customer: create(:customer), status: 'holding')
    price_the_order_with(priced)

    subscriber.handle(event_for(order))

    expect(other.reload.status).to eq('holding')
  end

  it 'settles nothing for an order that carries no seckill price' do
    ticket = claim(quantity: 1)

    subscriber.handle(event_for(order))

    expect(ticket.reload.status).to eq('holding')
  end

  it 'survives an order that no longer exists' do
    expect { subscriber.handle(double('Event', payload: { 'id' => 'order_gone' })) }.not_to raise_error
  end
end
