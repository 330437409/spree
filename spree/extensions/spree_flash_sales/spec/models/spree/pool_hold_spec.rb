require 'spec_helper'

RSpec.describe Spree::PoolHold do
  let(:flash_sale) { create(:flash_sale, pool_all: 2) }
  let(:pool) { Spree::FlashSale::Pool.for!(flash_sale: flash_sale, kind: 'all') }
  let(:ticket) { create(:flash_sale_ticket, flash_sale: flash_sale) }

  def reserve(quantity: 1, owner: ticket, expires_at: 5.minutes.from_now)
    described_class.reserve!(owner: owner, pool: pool, quantity: quantity, expires_at: expires_at)
  end

  it 'takes the units and records who holds them' do
    hold = reserve(quantity: 2)

    expect(hold).to be_present
    expect(hold.status).to eq('holding')
    expect(pool.reload.held).to eq(2)
  end

  it 'answers nothing when the pool has not got the units' do
    expect(reserve(quantity: 3)).to be_nil
    expect(pool.reload.held).to eq(0)
  end

  it 'gives the units back once, and only once' do
    hold = reserve(quantity: 2)

    expect(hold.release!).to be(true)
    expect(hold.release!).to be(false)

    expect(pool.reload.held).to eq(0)
    expect(hold.reload.status).to eq('released')
    expect(hold.released_at).to be_present
  end

  it 'sweeps what has lapsed and leaves what has not' do
    lapsed = reserve(quantity: 1, expires_at: 1.minute.ago)
    live = reserve(quantity: 1, expires_at: 5.minutes.from_now)

    expect(described_class.sweep_expired!).to eq(1)

    expect(lapsed.reload.status).to eq('released')
    expect(live.reload.status).to eq('holding')
    expect(pool.reload.held).to eq(1)
  end

  # The hold is invisible to the goods' own availability, which is the whole
  # reason it is not a `Spree::StockReservation`.
  it 'leaves the variant stock it never touches alone' do
    variant = ticket.variant
    before_count = Spree::Stock::Quantifier.new(variant).total_on_hand

    reserve(quantity: 2)

    expect(Spree::Stock::Quantifier.new(variant.reload).total_on_hand).to eq(before_count)
  end
end
