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
    # Nothing time-boxes a catalogue price, and no shop was named.
    expect(row.price_ends_at).to be_nil
    expect(row.stock_location_quantity).to be_nil
  end

  # The area context's own pair: what the goods have anywhere, and what the shop
  # the page is about has on its own shelf. Both figures travel, because the
  # client switches between them on what kind of basket it is building.
  it 'answers the named shop’s shelf beside the goods’ own' do
    variant.stock_levels.update_all(count_on_hand: 5, backorderable: false)
    warehouse = create(:stock_location, name: '浦东仓')
    create(:stock_level, variant: variant, stock_location: warehouse,
                         count_on_hand: 2, backorderable: false, adjust_count_on_hand: false)

    row = preview([{ variant: variant, quantity: 1 }], stock_location: warehouse).rows.first

    expect(row.available_quantity).to eq(7)
    expect(row.stock_location_quantity).to eq(2)
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
    closes_at = 2.hours.from_now
    price_list = create(:price_list, store: store, status: 'active', name: '区域价', ends_at: closes_at)
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
    expect(row.price_list_id).to eq(price_list.prefixed_id)
    # A list may carry a window, and then the price it answers is good until the
    # window closes — the instant the page's countdown renders.
    expect(row.price_ends_at).to be_within(1.second).of(closes_at)
  end

  # A source that prices a line is the price, so a window on the catalogue's own
  # list says nothing about it: the line answers no window rather than the one
  # belonging to the price it is not being charged.
  it 'answers no window when a source prices a line the catalogue time-boxes' do
    price_list = create(:price_list, store: store, status: 'active', name: '区域价', ends_at: 2.hours.from_now)
    create(:price, variant: variant, currency: store.default_currency, amount: 80, price_list: price_list)
    catalog = create(:catalog, store: store, price_list: price_list, active: true)
    Spree::Current.channel = create(:channel, store: store, default_catalog: catalog)

    source = Class.new do
      def self.call(variant:, quantity:, customer: nil, context: {})
        { amount: 60.0, label: 'test_source' }
      end
    end
    Spree.price_preview_sources.unshift(source)

    row = preview([{ variant: variant, quantity: 1 }]).rows.first

    expect(row.unit_amount).to eq(60)
    expect(row.price_ends_at).to be_nil
  ensure
    Spree.price_preview_sources.delete(source)
  end

  # A line nobody can price is not a free line, and nothing in it is for sale.
  it 'answers no price rather than a free one when nothing prices the variant' do
    variant.prices.destroy_all

    result = preview([{ variant: variant, quantity: 1 }])
    row = result.rows.first

    expect(row.unit_amount).to be_nil
    expect(row.total).to be_nil
    expect(result.total).to be_nil
    expect(result.purchasable?).to be(false)
  end

  # The quantity is what the caller asked for, and a basket of nothing is not a
  # basket: the service prices what it is given rather than guessing.
  it 'prices the quantity it is given, and only that' do
    expect(preview([{ variant: variant, quantity: 5 }]).total).to eq(500)
  end
end
