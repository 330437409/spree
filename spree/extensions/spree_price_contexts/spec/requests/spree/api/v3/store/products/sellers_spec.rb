require 'spec_helper'

RSpec.describe 'GET /api/v3/store/products/:id/sellers', type: :request do
  include_context 'API v3 Store'

  let(:headers) { api_key_headers }
  let(:product) { create(:product, store: store, slug: 'shared-listing') }
  # A shop's own name is Chinese here, and the slug is what it resolves by —
  # `Spree::Seller` derives one from the name and a Chinese name yields nothing
  # to derive from, so it is given.
  let(:seller) { create(:seller, :approved, store: store, name: '南山区水果店', slug: 'nanshan-fruit') }
  let(:suspended) { create(:seller, :suspended, store: store) }

  before do
    product.variants.destroy_all
    create(:variant, product: product, seller: seller, sku: 'S-1', price: 10)
    create(:variant, product: product, seller: suspended, sku: 'S-2', price: 20)
    product.reload
  end

  def request_sellers(id = product.prefixed_id)
    get "/api/v3/store/products/#{id}/sellers", headers: headers
  end

  # The client asks this before it rebinds its own site, so it answers for a
  # customer who has not signed in and carries nothing but the publishable key.
  it 'answers the sellers a shopper could buy from' do
    request_sellers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['data'].pluck('id')).to eq([seller.prefixed_id])
  end

  it 'describes each seller as the storefront does' do
    request_sellers

    expect(response.parsed_body['data'].first).to include(
      'id' => seller.prefixed_id, 'name' => '南山区水果店', 'slug' => seller.slug
    )
  end

  it 'carries the pagination a list carries' do
    request_sellers

    expect(response.parsed_body['meta']).to include('count' => 1, 'page' => 1)
  end

  it 'resolves the product by slug as well as by prefixed id' do
    request_sellers('shared-listing')

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['data'].pluck('id')).to eq([seller.prefixed_id])
  end

  it 'answers an empty list for a product only the operator sells' do
    product.variants.where.not(seller_id: nil).destroy_all

    request_sellers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['data']).to eq([])
    expect(response.parsed_body['meta']).to include('count' => 0)
  end

  it 'answers 404 for a product this store does not have' do
    request_sellers('prod_doesnotexist')

    expect(response).to have_http_status(:not_found)
  end

  # The product is looked up through the store's own association, so an id from
  # another tenant is a 404 rather than a foreign shop's sellers.
  it 'answers 404 for a product of another store' do
    other_store_product = create(:product, store: create(:store))

    request_sellers(other_store_product.prefixed_id)

    expect(response).to have_http_status(:not_found)
  end
end
