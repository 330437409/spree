require 'spec_helper'

RSpec.describe Spree::FlashSale::Pool do
  let(:flash_sale) { create(:flash_sale, pool_all: 3, pool_per_day: 0, pool_per_slot: 0) }
  let(:pool) { described_class.for!(flash_sale: flash_sale, kind: 'all') }

  it 'takes its cap from the record a merchant edits, not from a copy' do
    flash_sale.update!(pool_all: 7)

    expect(pool.cap).to eq(7)
  end

  it 'takes what it has and refuses what it has not' do
    expect(pool.reserve!(2)).to be(true)
    expect(pool.reserve!(2)).to be(false)

    expect(pool.reload.held).to eq(2)
    expect(pool.remaining).to eq(1)
  end

  it 'gives units back' do
    pool.reserve!(3)

    expect(pool.release!(2)).to be(true)
    expect(pool.reload.held).to eq(1)
  end

  it 'refuses to give back more than it holds' do
    pool.reserve!(1)

    expect(pool.release!(5)).to be(false)
    expect(pool.reload.held).to eq(1)
  end

  # Two customers claiming the last unit is the race the guard exists for: the
  # update itself carries the condition, so the second one changes nothing.
  it 'lets one of two simultaneous claims take the last unit' do
    same_pool = described_class.find(pool.id)
    pool.reserve!(3)

    expect(same_pool.reserve!(1)).to be(false)
    expect(pool.reload.held).to eq(3)
  end

  it 'is the same counter row however it is asked for' do
    first = described_class.for!(flash_sale: flash_sale, kind: 'all')
    second = described_class.for!(flash_sale: flash_sale, kind: 'all')

    expect(first.id).to eq(second.id)
  end

  it 'keeps a counter per day and per slot' do
    slot = create(:flash_sale_slot, flash_sale: flash_sale, pool: 5)

    today = described_class.for!(flash_sale: flash_sale, kind: 'day', on_date: Date.current)
    yesterday = described_class.for!(flash_sale: flash_sale, kind: 'day', on_date: Date.yesterday)
    slot_pool = described_class.for!(flash_sale: flash_sale, kind: 'slot', slot: slot)

    expect([today.id, yesterday.id, slot_pool.id].uniq.length).to eq(3)
    expect(slot_pool.cap).to eq(5)
    expect(today.cap).to eq(flash_sale.pool_per_day)
  end
end
