require 'spec_helper'

RSpec.describe 'GET /api/v3/store/sites', type: :request do
  include_context 'API v3 Store'
  include_context 'the division tree around 天安门'

  let(:latitude) { 39.9089 }
  let(:longitude) { 116.40347 }

  before do
    create(:reverse_geocode_cache,
           geohash: Spree::ReverseGeocode::Geohash.encode(latitude: latitude, longitude: longitude),
           provider: store.preferred_reverse_geocode_provider,
           dataset_version: release,
           district_code: '110101')
  end

  def request_sites(overrides = {})
    get '/api/v3/store/sites', params: { latitude: latitude, longitude: longitude }.merge(overrides),
                               headers: api_key_headers
  end

  def site_ids
    response.parsed_body['data'].map { |seller| seller['id'] }
  end

  def seller_bound_to(division, **attributes)
    seller = create(:seller, :approved, store: store)
    create(:stock_location, seller: seller, store: store, administrative_division: division, **attributes)
    seller
  end

  it 'answers the sellers serving the province the point falls in' do
    district = seller_bound_to(dongcheng, name: '东城仓')

    request_sites

    expect(response).to have_http_status(:ok)
    expect(site_ids).to eq([district.prefixed_id])
  end

  it 'includes a seller bound to the province itself, and one bound deeper than the point' do
    province = seller_bound_to(beijing)
    township = seller_bound_to(donghuamen)

    request_sites

    expect(site_ids).to contain_exactly(province.prefixed_id, township.prefixed_id)
  end

  it 'leaves out a seller bound in another province' do
    seller_bound_to(shanghai)

    request_sites

    expect(response.parsed_body['data']).to be_empty
  end

  it 'leaves out an inactive warehouse and a seller who cannot sell' do
    seller_bound_to(dongcheng, active: false)

    onboarding = create(:seller, :onboarding, store: store)
    create(:stock_location, seller: onboarding, store: store, administrative_division: dongcheng)

    request_sites

    expect(response.parsed_body['data']).to be_empty
  end

  it 'answers nothing for a point that resolves to no division' do
    seller_bound_to(dongcheng)
    Spree::ReverseGeocodeCache.update_all(resolved: false, province_code: nil, city_code: nil, district_code: nil)

    request_sites

    expect(response.parsed_body['data']).to be_empty
  end

  it 'is readable by a shopper who is not signed in' do
    request_sites

    expect(response).to have_http_status(:ok)
  end

  describe 'the cities read' do
    it 'answers the cities a site is bound in' do
      seller_bound_to(dongcheng)

      get '/api/v3/store/sites/cities', headers: api_key_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data']).to contain_exactly(
        'code' => '110100', 'name' => '市辖区', 'level' => 'city'
      )
    end

    it 'takes no parameters' do
      get '/api/v3/store/sites/cities', headers: api_key_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data']).to be_empty
    end

    it 'puts no city on the list for a binding at the province level' do
      seller_bound_to(beijing)

      get '/api/v3/store/sites/cities', headers: api_key_headers

      expect(response.parsed_body['data']).to be_empty
    end

    it 'lists a city once however many warehouses are bound inside it' do
      seller_bound_to(dongcheng)
      seller_bound_to(shixiaqu)

      get '/api/v3/store/sites/cities', headers: api_key_headers

      expect(response.parsed_body['data'].length).to eq(1)
    end
  end

  describe 'refusals' do
    it 'refuses a missing coordinate' do
      get '/api/v3/store/sites', params: { longitude: longitude }, headers: api_key_headers

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']['code']).to eq('parameter_missing')
    end

    it 'refuses a point that is not on Earth' do
      request_sites(latitude: 91)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'refuses a request with no publishable key' do
      get '/api/v3/store/sites', params: { latitude: latitude, longitude: longitude }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
