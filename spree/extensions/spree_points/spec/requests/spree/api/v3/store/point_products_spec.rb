require 'spec_helper'

RSpec.describe 'GET /api/v3/store/point_products', type: :request do
  include_context 'API v3 Store guest'

  let(:seller) { create(:seller, store: store) }
  let!(:cups) { create(:point_product, store: store, name: 'A cup', category: 'cups', position: 1) }
  let!(:featured) { create(:point_product, store: store, name: 'A teapot', category: 'pots', position: 2, featured: true) }
  let!(:sold_out) { create(:point_product, store: store, name: 'A kettle', stock: 0, position: 3) }

  def shelf(**params)
    get '/api/v3/store/point_products', headers: api_key_headers, params: params
  end

  it 'answers the shelf in the operator’s own order, with the labels above it' do
    shelf

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['data'].map { |row| row['name'] }).to eq(['A cup', 'A teapot', 'A kettle'])
    expect(response.parsed_body['meta']['categories']).to eq(%w[cups pots])
  end

  it 'narrows to one label' do
    shelf(category: 'pots')

    expect(response.parsed_body['data'].map { |row| row['name'] }).to eq(['A teapot'])
  end

  # The labels are what the client switches pages with, so a page narrowed to
  # one of them still carries all of them.
  it 'answers the labels of the whole shelf while the page is one label' do
    shelf(category: 'pots')

    expect(response.parsed_body['meta']['categories']).to eq(%w[cups pots])
  end

  it 'answers the featured shelf alone' do
    shelf(featured: true)

    expect(response.parsed_body['data'].map { |row| row['name'] }).to eq(['A teapot'])
  end

  it 'says what a good costs and whether it is on the shelf' do
    shelf

    row = response.parsed_body['data'].first
    expect(row).to include('type' => 'good', 'points' => 100, 'money' => '0.0', 'in_stock' => true)
    expect(response.parsed_body['data'].last['in_stock']).to be(false)
  end

  # 加钱购 is a price like any other, so a channel that hides prices hides it.
  it 'hides the money figure on a channel that hides prices' do
    create(:channel, store: store, code: 'gated', preferred_storefront_access: 'prices_hidden')

    get '/api/v3/store/point_products', headers: api_key_headers.merge('X-Spree-Channel' => 'gated')

    expect(response.parsed_body['data'].first['money']).to be_nil
  end

  it 'answers this store’s goods alone' do
    create(:point_product, store: create(:store), name: 'Another shop’s cup', category: 'toys')
    shelf

    expect(response.parsed_body['data'].map { |row| row['name'] }).not_to include('Another shop’s cup')
    expect(response.parsed_body['meta']['categories']).to eq(%w[cups pots])
  end

  # The seller is resolved from the header the mini program maps its `siteId`
  # onto, so the shelf follows the request rather than a global.
  it 'answers the member shelf, which is the seller’s own goods beside the store’s' do
    create(:point_product, store: store, name: 'My cup', seller: seller)
    create(:point_product, store: store, name: 'Their cup', seller: create(:seller, store: store))

    get '/api/v3/store/point_products', headers: api_key_headers.merge('X-Spree-Seller-Id' => seller.prefixed_id),
                                        params: { audience: 'member' }

    names = response.parsed_body['data'].map { |row| row['name'] }
    expect(names).to include('My cup', 'A cup')
    expect(names).not_to include('Their cup')
  end

  # A shelf silently missing a seller's goods reads as a shelf with nothing in
  # it, so a member shelf that names no site is refused rather than narrowed.
  it 'refuses the member shelf when the request named no site' do
    shelf(audience: 'member')

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']['code']).to eq('parameter_invalid')
  end
end

RSpec.describe 'GET /api/v3/store/point_products/:id', type: :request do
  include_context 'API v3 Store guest'

  let(:group) { create(:customer_group) }
  let!(:card) do
    create(:point_vip_card_product, store: store, name: 'A gold card', points: 5_000, customer_group: group)
  end

  it 'answers one good with what it issues' do
    get "/api/v3/store/point_products/#{card.prefixed_id}", headers: api_key_headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('type' => 'vip_card', 'name' => 'A gold card', 'points' => 5_000)
    expect(response.parsed_body['vip_card']).to include('name' => group.name)
    expect(response.parsed_body['variant_id']).to be_nil
  end

  it 'answers 404 for an id this store does not have' do
    get '/api/v3/store/point_products/ptgood_0000000000', headers: api_key_headers

    expect(response).to have_http_status(:not_found)
  end
end
