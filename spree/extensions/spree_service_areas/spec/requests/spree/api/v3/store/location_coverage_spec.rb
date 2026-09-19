require 'spec_helper'

RSpec.describe 'GET /api/v3/store/location/coverage', type: :request do
  include_context 'API v3 Store'
  include_context 'the division tree around 天安门'

  let(:latitude) { 39.9089 }
  let(:longitude) { 116.40347 }
  let(:seller) { create(:seller, :approved, store: store) }
  let(:warehouse) do
    create(:stock_location, seller: seller, store: store, administrative_division: dongcheng, name: '东城仓')
  end

  before do
    create(:reverse_geocode_cache,
           geohash: Spree::ReverseGeocode::Geohash.encode(latitude: latitude, longitude: longitude),
           provider: store.preferred_reverse_geocode_provider,
           dataset_version: release,
           district_code: '110101')
  end

  def check(overrides = {})
    get '/api/v3/store/location/coverage',
        params: { latitude: latitude, longitude: longitude }.merge(overrides),
        headers: api_key_headers.merge('X-Spree-Seller-Id' => seller.prefixed_id)
  end

  def serves?
    response.parsed_body['serves']
  end

  it 'answers that a named warehouse serves the point it is bound around' do
    warehouse

    check(warehouse_id: warehouse.prefixed_id)

    expect(response).to have_http_status(:ok)
    expect(serves?).to be true
  end

  it 'answers that it does not serve a point in another province' do
    warehouse
    # The same cell, answered for Shanghai instead — the point the customer is
    # asking about is the one the provider placed, not the one the warehouse is in.
    Spree::ReverseGeocodeCache.update_all(district_code: '310101')

    check(warehouse_id: warehouse.prefixed_id)

    expect(serves?).to be false
  end

  it 'narrows by polygon when the warehouse carries one' do
    around_shanghai = [[[121.40, 31.15], [121.60, 31.15], [121.60, 31.25], [121.40, 31.25], [121.40, 31.15]]]
    warehouse.update!(polygon: around_shanghai)

    check(warehouse_id: warehouse.prefixed_id)

    expect(serves?).to be false
  end

  it 'answers for the whole seller when no warehouse is named' do
    warehouse

    check

    expect(serves?).to be true
  end

  it 'answers that a seller with no binding serves nothing' do
    check

    expect(serves?).to be false
  end

  it 'refuses a warehouse that is not this seller’s' do
    other = create(:stock_location, seller: create(:seller, :approved, store: store), store: store,
                                    administrative_division: dongcheng)

    check(warehouse_id: other.prefixed_id)

    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body['error']['code']).to eq('record_not_found')
  end
end
