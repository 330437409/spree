require 'spec_helper'

RSpec.describe 'the reporting vocabulary this gem contributes' do
  let(:store) { @default_store }
  let(:price_list) { create(:price_list, store: store, name: '区域价') }
  let!(:order) { create(:completed_order_with_totals, store: store, completed_at: 3.days.ago) }
  let(:listed_line) { order.line_items.first }

  def run(params)
    Spree::Reporting::Query.new(store: store, params: params).execute
  end

  def by_dimension(name)
    run(metrics: %w[gross_sales], dimensions: [name]).rows.to_h do |row|
      [row[:dimensions][name.to_sym], row[:metrics][:gross_sales][:value]]
    end
  end

  it 'publishes both provenance dimensions to the schema' do
    schema = Spree::Reporting::Schema.new(store: store).to_h
    names = schema[:dimensions].map { |entry| entry[:name] }

    expect(names).to include(:price_list, :price_source)
  end

  # The plan's constraint: a report has to say which price it is reading, so a
  # line a list priced is grouped apart from one that carries a base price.
  it 'separates the prices a list set from the base prices' do
    listed_line.update_columns(price_list_id: price_list.id)

    expect(by_dimension('price_list')).to eq(
      price_list.id => (listed_line.price * listed_line.quantity).to_f.round(2)
    )
  end

  it 'groups the lines no list priced under no list at all' do
    expect(by_dimension('price_list')).to eq(nil => (listed_line.price * listed_line.quantity).to_f.round(2))
  end

  it 'tells a negotiated price apart from one the platform priced' do
    listed_line.update_columns(price_source: Spree::PricingProvider::MANUAL_PRICE_SOURCE)
    second = create(:line_item, order: order, price: 5, quantity: 1)

    expect(by_dimension('price_source')).to eq(
      'manual' => (listed_line.price * listed_line.quantity).to_f.round(2),
      nil => (second.price * second.quantity).to_f.round(2)
    )
  end

  # Hydration runs inside API requests, so nothing else exercises the label the
  # report builder shows for a context's list.
  it "labels a list with the operator's own name for it" do
    hydrated = Spree.reporting.dimension!(:price_list).hydrate.call(store, [price_list.id], {})

    expect(hydrated[price_list.id]).to include(id: price_list.prefixed_id, label: '区域价')
  end

  it 'resolves a prefixed list id a filter names, and hydrates it with its name' do
    listed_line.update_columns(price_list_id: price_list.id)

    result = run(metrics: %w[gross_sales], dimensions: %w[price_list],
                 filters: [{ dimension: 'price_list', op: 'eq', value: price_list.prefixed_id }])

    expect(result.rows.length).to eq(1)
    expect(result.rows.first[:dimensions][:price_list]).to eq(price_list.id)
  end
end
