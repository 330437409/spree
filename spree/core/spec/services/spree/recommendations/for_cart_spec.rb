require 'spec_helper'

RSpec.describe Spree::Recommendations::ForCart do
  let(:store) { @default_store }
  let(:cart) { create(:cart_with_line_items, store: store) }
  let(:books) { create(:category, store: store, name: 'Books') }
  let(:music) { create(:category, store: store, name: 'Music') }

  subject(:result) { described_class.call(cart: cart, scope: Spree::Product.for_store(store)) }

  before do
    cart.line_items.each { |line_item| line_item.product.categories << books }
  end

  def product_in(category, name:, sold: 0)
    create(:product, store: store, name: name).tap do |product|
      product.categories << category
      product.update_columns(units_sold_count: sold)
    end
  end

  it 'offers goods from the categories the basket is in' do
    recommended = product_in(books, name: 'Another book')

    expect(result).to be_success
    expect(result.value).to include(recommended)
  end

  it 'offers nothing from a category the basket has nothing in' do
    elsewhere = product_in(music, name: 'A record')

    expect(result.value).not_to include(elsewhere)
  end

  # What is already in front of the shopper is not a recommendation.
  it 'offers nothing that is already in the basket' do
    expect(result.value).not_to include(cart.line_items.first.product)
  end

  it 'leads with what sells' do
    quiet = product_in(books, name: 'Quiet book', sold: 1)
    popular = product_in(books, name: 'Popular book', sold: 500)

    expect(result.value.index(popular)).to be < result.value.index(quiet)
  end

  it 'answers nothing when the basket is in no category' do
    cart.line_items.each { |line_item| line_item.product.categories.destroy_all }

    expect(result.value).to be_empty
  end

  it 'answers as many as it was asked for' do
    3.times { |n| product_in(books, name: "Book #{n}") }

    expect(described_class.call(cart: cart, scope: Spree::Product.for_store(store), limit: 2).value.size).to eq(2)
  end

  # The catalogue the caller passes decides what may be answered at all: a
  # recommendation is not a way around what the storefront shows.
  it 'never answers outside the scope it was given' do
    product_in(books, name: 'Another book')
    elsewhere = create(:product, store: create(:store))

    expect(result.value).not_to include(elsewhere)
  end
end
