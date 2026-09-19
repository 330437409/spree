require 'spec_helper'

RSpec.describe 'GET /api/v3/store/service_areas/taken', type: :request do
  include_context 'API v3 Store'
  include_context 'the division tree around 天安门'

  def check(code = '110101')
    get '/api/v3/store/service_areas/taken', params: { division_code: code }, headers: api_key_headers
  end

  def taken?
    response.parsed_body['taken']
  end

  it 'answers that a node an active warehouse holds is taken' do
    create(:stock_location, store: store, administrative_division: dongcheng)

    check

    expect(response).to have_http_status(:ok)
    expect(taken?).to be true
  end

  it 'answers that it is free when the only warehouse holding it is deactivated' do
    create(:stock_location, store: store, administrative_division: dongcheng, active: false)

    check

    expect(taken?).to be false
  end

  it 'answers that a code this release does not carry is taken by nobody' do
    check('999999')

    expect(response).to have_http_status(:ok)
    expect(taken?).to be false
  end

  it 'is readable by a prospective seller who is not signed in' do
    check

    expect(response).to have_http_status(:ok)
  end

  it 'refuses a request that names no division' do
    get '/api/v3/store/service_areas/taken', headers: api_key_headers

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body['error']['code']).to eq('parameter_missing')
  end
end
