require 'spec_helper'

RSpec.describe SpreeFlashSales::PricePreviewSource do
  let(:store) { @default_store }
  let(:flash_sale) { create(:flash_sale, store: store, pool_all: 10) }
  let(:variant) { create(:product, store: store, price: 100).default_variant }
  let!(:item) { create(:flash_sale_item, flash_sale: flash_sale, variant: variant, sale_amount: 60, pool: 0) }

  def preview(context = {})
    Spree::PricePreview.call(items: [{ variant: variant, quantity: 1 }], context: context).value
  end

  it 'prices the line at the activity’s own price, with the catalogue beside it' do
    row = preview(flash_sale_id: flash_sale.prefixed_id).rows.first

    expect(row.unit_amount).to eq(60)
    expect(row.source).to eq('flash_sale')
    expect(row.compare_at_amount).to eq(100)
  end

  it 'carries the verdicts the settle page renders' do
    flags = preview(flash_sale_id: flash_sale.prefixed_id).flags

    expect(flags['allows_points']).to be(false)
    expect(flags['allows_coupons']).to be(false)
    expect(flags['claimable']).to be(true)
    expect(flags['flash_sale_id']).to eq(flash_sale.prefixed_id)
    expect(flags['flash_sale_status']).to eq('live')
  end

  # An activity that has not opened, or has closed, prices nothing: the line is
  # the catalogue's.
  it 'declines an activity whose window is not open' do
    flash_sale.update!(starts_at: 1.hour.from_now, ends_at: 3.hours.from_now)

    expect(preview(flash_sale_id: flash_sale.prefixed_id).rows.first.source).to be_nil
  end

  it 'declines a request that names no activity' do
    expect(preview.rows.first.source).to be_nil
    expect(preview.rows.first.unit_amount).to eq(100)
  end

  it 'declines an activity that does not sell this goods' do
    other = create(:flash_sale, store: store)

    expect(preview(flash_sale_id: other.prefixed_id).rows.first.source).to be_nil
  end

  # The price the activity answers is good for as long as it is offered: the
  # close of the stretch it is sold in, or the window's own end when it is sold
  # throughout. This is the instant the page's countdown renders.
  it 'answers when the price stops being offered' do
    expect(preview(flash_sale_id: flash_sale.prefixed_id).rows.first.price_ends_at)
      .to be_within(1.second).of(flash_sale.ends_at)

    slot = create(:flash_sale_slot, flash_sale: flash_sale, pool: 10)

    expect(preview(flash_sale_id: flash_sale.prefixed_id).rows.first.price_ends_at)
      .to be_within(1.second).of(slot.ends_at)
  end

  # A pool that has run out is not a price: the page should not offer the
  # seckill for units nobody can claim.
  it 'says an activity is not claimable once its pool is gone' do
    flash_sale.pools.create!(kind: 'all', key: 'all', held: 10)

    expect(preview(flash_sale_id: flash_sale.prefixed_id).flags['claimable']).to be(false)
  end

  # A cart being priced does not have to say which activity each line came from:
  # the ticket the customer holds does, and it is their own.
  describe 'when the request names no activity' do
    let(:customer) { create(:customer) }
    let(:slot) { create(:flash_sale_slot, flash_sale: flash_sale, pool: 10) }

    def preview_as(customer)
      Spree::PricePreview.call(items: [{ variant: variant, quantity: 1 }], customer: customer).value
    end

    it 'prices from the ticket the customer is holding' do
      Spree::FlashSales::ClaimTicket.call(customer: customer, item: item, quantity: 1, slot: slot)

      expect(preview_as(customer).rows.first.unit_amount).to eq(60)
    end

    it 'prices nothing from another customer’s ticket' do
      Spree::FlashSales::ClaimTicket.call(customer: create(:customer), item: item, quantity: 1, slot: slot)

      expect(preview_as(customer).rows.first.unit_amount).to eq(100)
    end

    it 'prices nothing once the ticket is gone' do
      ticket = Spree::FlashSales::ClaimTicket.call(customer: customer, item: item, quantity: 1, slot: slot).value
      ticket.release!(reason: 'canceled')

      expect(preview_as(customer).rows.first.unit_amount).to eq(100)
    end
  end

  # The settle page's call brings a cart, and this is where the price is written
  # onto the lines it holds.
  describe 'when the request brings a cart' do
    let(:customer) { create(:customer) }
    let(:slot) { create(:flash_sale_slot, flash_sale: flash_sale, pool: 10) }
    let(:cart) { create(:cart, store: store, customer: customer) }

    it 'writes the activity’s price onto the cart' do
      create(:line_item, cart: cart, variant: variant, quantity: 2, price: 100)
      ticket = Spree::FlashSales::ClaimTicket.call(customer: customer, item: item, quantity: 2, slot: slot).value

      described_class.apply!(cart: cart, customer: customer)

      expect(cart.reload.total.to_d).to eq(120)
      expect(cart.discounts.where(code: "flash_sale:#{ticket.prefixed_id}").count).to eq(1)
    end

    it 'leaves another customer’s cart alone' do
      create(:line_item, cart: cart, variant: variant, quantity: 1, price: 100)
      Spree::FlashSales::ClaimTicket.call(customer: create(:customer), item: item, quantity: 1, slot: slot)

      described_class.apply!(cart: cart, customer: customer)

      expect(cart.reload.discounts.count).to eq(0)
    end

    it 'does nothing for a guest' do
      create(:line_item, cart: cart, variant: variant, quantity: 1, price: 100)

      expect { described_class.apply!(cart: cart, customer: nil) }.not_to change { cart.reload.discounts.count }
    end
  end
end
