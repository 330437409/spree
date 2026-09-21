require 'spec_helper'

RSpec.describe 'the cart’s recommendations', type: :request do
  include_context 'API v3 Store'

  let(:store) { @default_store }
  let(:cart) { create(:cart, store: store) }
  let(:headers) { { 'x-spree-api-key' => api_key.token, 'x-spree-token' => cart.token } }
  let!(:tea) { create(:line_item, cart: cart, quantity: 1, price: 100) }
  let(:tea_category) { create(:category, store: store, name: 'Tea') }

  before { tea.product.categories << tea_category }

  def recommendations
    get "/api/v3/store/carts/#{cart.prefixed_id}/recommendations", headers: headers
    response.parsed_body['data'].map { |product| product['name'] }
  end

  it 'offers other goods from the categories the basket is in' do
    other_tea = create(:product, store: store, name: 'Another tea')
    other_tea.categories << tea_category

    expect(recommendations).to include('Another tea')
  end

  it 'does not offer what is already in the basket' do
    expect(recommendations).not_to include(tea.product.name)
  end

  # A recommendation is a read of the storefront's own catalogue, not a way
  # around it.
  it 'does not offer another store’s goods' do
    elsewhere = create(:product, store: create(:store), name: 'Tea from elsewhere')
    elsewhere.categories << create(:category, store: elsewhere.store, name: 'Tea')

    expect(recommendations).not_to include('Tea from elsewhere')
  end

  it 'offers nothing when the basket is in no category' do
    tea.product.categories.destroy_all

    expect(recommendations).to eq([])
  end

  it 'answers as many as the caller asked for' do
    3.times { |n| create(:product, store: store, name: "Tea #{n}").categories << tea_category }

    get "/api/v3/store/carts/#{cart.prefixed_id}/recommendations", headers: headers, params: { limit: 2 }

    expect(response.parsed_body['data'].size).to eq(2)
  end

  # A guest holds the cart token and nothing else, and the shelf is theirs
  # only with it: the cart read's own access policy refuses a caller who
  # cannot prove the cart is theirs.
  it 'refuses a caller who cannot prove the cart is theirs' do
    get "/api/v3/store/carts/#{cart.prefixed_id}/recommendations", headers: { 'x-spree-api-key' => api_key.token }

    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body['error']['code']).to eq('access_denied')
  end
end
