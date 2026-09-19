require 'spec_helper'

RSpec.describe 'GET /api/v3/store/location/resolve_seller', type: :request do
  include_context 'API v3 Store'

  let(:headers) { api_key_headers }
  let(:release) { 'nbs-2023-06-30' }
  let(:latitude) { 39.9089 }
  let(:longitude) { 116.40347 }

  let!(:nation) do
    create(:administrative_division, code: 'CN', name: '全国', level: 'country', depth: 0, dataset_version: release)
  end
  let!(:beijing) do
    create(:administrative_division, code: '110000', name: '北京市', level: 'province', depth: 1,
                                     parent: nation, dataset_version: release)
  end
  let!(:shixiaqu) do
    create(:administrative_division, code: '110100', name: '市辖区', level: 'city', depth: 2,
                                     parent: beijing, dataset_version: release)
  end
  let!(:dongcheng) do
    create(:administrative_division, code: '110101', name: '东城区', level: 'district', depth: 3,
                                     parent: shixiaqu, dataset_version: release)
  end

  let(:seller) { create(:seller, :approved, store: store) }
  let!(:warehouse) do
    create(:stock_location, seller: seller, administrative_division: dongcheng, store: store, name: '南山区仓')
  end

  let(:params) { { latitude: latitude, longitude: longitude } }

  def resolve(overrides = {})
    get '/api/v3/store/location/resolve_seller', params: params.merge(overrides), headers: headers
  end

  before do
    create(:reverse_geocode_cache,
           geohash: Spree::ReverseGeocode::Geohash.encode(latitude: latitude, longitude: longitude),
           provider: store.preferred_reverse_geocode_provider,
           dataset_version: release,
           district_code: '110101')
  end

  it 'answers the seller that serves the point' do
    resolve

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body['matched']).to be true
    expect(body['match_type']).to eq('district')
    expect(body['polygon_result']).to eq('not_required')
    expect(body['stale']).to be false
    expect(body['seller']).to include('id' => seller.prefixed_id, 'name' => seller.name)
    expect(body['administrative_division']).to eq('code' => '110101', 'name' => '东城区', 'level' => 'district')
    expect(body['warehouse']).to include('name' => '南山区仓')
  end

  it 'answers a shopper who is not signed in' do
    resolve

    expect(response).to have_http_status(:ok)
  end

  it 'refuses a request with no publishable key' do
    get '/api/v3/store/location/resolve_seller', params: params

    expect(response).to have_http_status(:unauthorized)
  end

  it 'answers no service rather than an error when no seller covers the point' do
    warehouse.destroy

    resolve

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('matched' => false, 'seller' => nil, 'match_type' => nil)
  end

  describe 'the coordinate it is given' do
    it 'accepts a WGS-84 pair and does the conversion itself' do
      resolve(latitude: 39.9075, longitude: 116.39723, coordinate_system: 'wgs84')

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['matched']).to be true
    end

    it 'refuses a pair in a system it does not know' do
      resolve(coordinate_system: 'bd09')

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']['code']).to eq('invalid_request')
      expect(response.parsed_body['error']['message']).to match(/unknown coordinate_system/)
    end

    it 'refuses a missing coordinate' do
      get '/api/v3/store/location/resolve_seller', params: { longitude: longitude }, headers: headers

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']['code']).to eq('parameter_missing')
    end

    it 'refuses a coordinate that is not a number' do
      resolve(latitude: 'north')

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']['code']).to eq('invalid_request')
    end

    it 'refuses a point that is not on Earth' do
      resolve(latitude: 91)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']['message']).to match(/latitude and longitude/)
    end
  end

  describe 'a client that asks too often' do
    before do
      allow(Spree::SellerRouting::RateLimit).to receive(:allow?).and_return(false)
    end

    it 'answers 429 with the code the client can switch on' do
      resolve

      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body['error']['code']).to eq('rate_limit_exceeded')
    end

    it 'counts per store and per caller, so one client cannot spend another’s' do
      resolve

      expect(Spree::SellerRouting::RateLimit).to have_received(:allow?).with(
        hash_including(key: "spree_seller_routing/#{store.id}/127.0.0.1",
                       limit: Spree::Api::V3::Store::Location::ResolveSellerController::RATE_LIMIT_CALLS)
      )
    end
  end

  describe 'when the point cannot be placed' do
    let(:provider) { instance_double(Spree::ReverseGeocode::Tencent) }

    before do
      Spree::ReverseGeocodeCache.delete_all
      allow(Spree::ReverseGeocode::Tencent).to receive(:new).and_return(provider)
      allow(provider).to receive(:reverse_geocode).
        and_raise(Spree::ReverseGeocode::ApiError.new('Tencent LBS refused the reverse geocoding request: 此key每日调用量已达到上限'))
    end

    it 'answers 503 with a code the client can switch on, and the provider’s own words' do
      resolve

      expect(response).to have_http_status(:service_unavailable)
      expect(response.parsed_body['error']['code']).to eq('reverse_geocode_unavailable')
      expect(response.parsed_body['error']['message']).to match(/此key每日调用量已达到上限/)
    end

    context 'with an expired answer cached' do
      before do
        create(:reverse_geocode_cache,
               geohash: Spree::ReverseGeocode::Geohash.encode(latitude: latitude, longitude: longitude),
               provider: store.preferred_reverse_geocode_provider,
               dataset_version: release,
               district_code: '110101',
               expires_at: 1.day.ago)
      end

      it 'answers the old one and says it is old' do
        resolve

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['stale']).to be true
        expect(response.parsed_body['matched']).to be true
      end
    end
  end
end
