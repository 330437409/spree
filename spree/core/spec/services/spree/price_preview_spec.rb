require 'spec_helper'

RSpec.describe Spree::PricePreview do
  let(:store) { @default_store }
  let(:product) { create(:product, store: store, price: 100) }
  let(:variant) { product.default_variant }

  def preview(items, **options)
    described_class.call(items: items, **options).value
  end

  it 'prices a variant and totals what was asked for' do
    result = preview([{ variant: variant, quantity: 2 }])
    row = result.rows.first

    expect(row.unit_amount).to eq(100)
    expect(row.total).to eq(200)
    expect(result.total).to eq(200)
    expect(result.currency).to eq(store.default_currency)
  end

  it 'answers the shelf, and claims nothing on it' do
    variant.stock_levels.update_all(count_on_hand: 3, backorderable: false)
    row = preview([{ variant: variant, quantity: 2 }]).rows.first

    expect(row.available_quantity).to eq(3)
    expect(row.in_stock).to be(true)
    expect(row.purchasable).to be(true)
  end

  it 'says so when there is nothing on the shelf' do
    variant.stock_levels.update_all(count_on_hand: 0, backorderable: false)
    row = preview([{ variant: variant, quantity: 1 }]).rows.first

    expect(row.in_stock).to be(false)
    expect(row.purchasable).to be(false)
  end

  it 'answers one row per line and nothing for an empty ask' do
    expect(preview([{ variant: variant, quantity: 1 }, { variant: variant, quantity: 3 }]).rows.length).to eq(2)
    expect(preview([]).rows).to be_empty
    expect(preview([]).total).to eq(0)
  end

  # The route exists so there is one price calculation, so the price it answers
  # has to be the one the cart would write — resolved through the request's own
  # channel, whose catalog carries the list.
  it 'answers the price the request context resolves, with the base beside it' do
    price_list = create(:price_list, store: store, status: 'active', name: '区域价')
    create(:price, variant: variant, currency: store.default_currency, amount: 80, price_list: price_list)
    catalog = create(:catalog, store: store, price_list: price_list, active: true)
    channel = create(:channel, store: store, default_catalog: catalog)
    Spree::Current.channel = channel

    row = preview([{ variant: variant, quantity: 1 }]).rows.first

    expect(row.unit_amount).to eq(80)
    expect(row.compare_at_amount).to eq(100)
    # The internal walk stamps no `price_source` — a provider that answered names
    # itself there — so the list is what says where this price came from.
    expect(row.price_source).to be_nil
    expect(row.price_list_id).to eq(price_list.id)
  end
end
