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

  # A pool that has run out is not a price: the page should not offer the
  # seckill for units nobody can claim.
  it 'says an activity is not claimable once its pool is gone' do
    flash_sale.pools.create!(kind: 'all', key: 'all', held: 10)

    expect(preview(flash_sale_id: flash_sale.prefixed_id).flags['claimable']).to be(false)
  end
end
