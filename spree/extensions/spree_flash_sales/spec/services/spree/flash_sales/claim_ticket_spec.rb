require 'spec_helper'

RSpec.describe Spree::FlashSales::ClaimTicket do
  let(:store) { @default_store }
  let(:flash_sale) do
    create(:flash_sale, store: store, pool_all: 10, pool_per_day: 10, pool_per_slot: 10)
  end
  let(:slot) { create(:flash_sale_slot, flash_sale: flash_sale, pool: 10) }
  let(:variant) { create(:variant).tap { |record| record.stock_levels.update_all(count_on_hand: 10, backorderable: false) } }
  let(:item) { create(:flash_sale_item, flash_sale: flash_sale, variant: variant, pool: 10) }
  let(:customer) { create(:customer) }

  def claim(quantity: 1, **overrides)
    described_class.call(customer: customer, item: item, quantity: quantity, slot: slot, **overrides)
  end

  def held(pool_kind, **key)
    flash_sale.pools.where(kind: pool_kind.to_s, **key).pick(:held).to_i
  end

  it 'gives the customer a ticket holding the units they asked for' do
    result = claim(quantity: 2)

    expect(result).to be_success
    ticket = result.value
    expect(ticket).to be_holding
    expect(ticket.quantity).to eq(2)
    expect(ticket.expires_at).to be_within(5.seconds).of(5.minutes.from_now)
  end

  it 'takes the units from every scope the client intersects' do
    claim(quantity: 2)

    expect(held(:all)).to eq(2)
    expect(held(:day)).to eq(2)
    expect(held(:slot)).to eq(2)
    expect(held(:item)).to eq(2)
  end

  it 'refuses a claim before the window opens' do
    flash_sale.update!(starts_at: 1.hour.from_now, ends_at: 3.hours.from_now)

    expect(claim.value).to eq(:not_started)
  end

  it 'refuses a claim after the window closes' do
    flash_sale.update!(starts_at: 3.hours.ago, ends_at: 1.minute.ago)

    expect(claim.value).to eq(:ended)
  end

  it 'refuses a claim the pool has not got, and holds nothing' do
    flash_sale.update!(pool_all: 1)

    expect(claim(quantity: 2).value).to eq(:sold_out)
    expect(flash_sale.pools.sum(:held)).to eq(0)
    expect(Spree::FlashSaleTicket.holding.count).to eq(0)
  end

  # The pool is a cap, never a substitute for stock: a shop with one unit on the
  # shelf cannot sell two because the activity promised ten.
  it 'refuses a claim the shelf has not got, however large the pool is' do
    variant.stock_levels.update_all(count_on_hand: 1)

    expect(claim(quantity: 2).value).to eq(:stock_short)
    expect(flash_sale.pools.sum(:held)).to eq(0)
  end

  it 'refuses a claim past the customer’s own cap' do
    flash_sale.update!(purchase_cap_all: 2, purchase_cap_day: 2)

    expect(claim(quantity: 3).value).to eq(:cap_reached)
  end

  # A replacement is not a second purchase: the cap measures what the customer
  # ends up holding, so replacing three with one is still one.
  it 'counts the ticket a re-claim replaces as replaced, not as bought' do
    flash_sale.update!(purchase_cap_day: 3)
    held = claim(quantity: 3).value

    expect(claim(quantity: 4, replacing: held).value).to eq(:cap_reached)
    expect(claim(quantity: 1, replacing: held)).to be_success
  end

  it 'counts what the customer has already bought against their cap' do
    flash_sale.update!(purchase_cap_all: 3)
    create(:flash_sale_ticket, flash_sale: flash_sale, variant: variant, customer: customer,
                               quantity: 3, status: 'settled')

    expect(claim(quantity: 1).value).to eq(:cap_reached)
  end

  it 'leaves a customer with one live ticket, not two' do
    claim(quantity: 1)
    second = claim(quantity: 1)

    expect(second).to be_failure
    expect(Spree::FlashSaleTicket.holding.count).to eq(1)
  end

  # Re-claiming replaces: the old hold and the new one are one transaction, so a
  # customer cannot hold units twice by asking twice.
  it 'releases the ticket a re-claim replaces, in the same breath' do
    first = claim(quantity: 2).value
    second = claim(quantity: 3, replacing: first)

    expect(second).to be_success
    expect(first.reload.status).to eq('replaced')
    expect(held(:all)).to eq(3)
    expect(Spree::FlashSaleTicket.holding.count).to eq(1)
  end

  # An activity that runs in slots needs one named, because the slot is what the
  # pool and the reminder are keyed to.
  it 'refuses a claim that names no slot while the activity runs in slots' do
    slot.update!(starts_at: 2.hours.ago, ends_at: 1.hour.ago)

    expect(claim(quantity: 1, slot: nil).value).to eq(:slot_required)
  end
end
