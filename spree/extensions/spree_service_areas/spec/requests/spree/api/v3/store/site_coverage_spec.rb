require 'spec_helper'

RSpec.describe 'GET /api/v3/store/site/coverage', type: :request do
  include_context 'API v3 Store'
  include_context 'the division tree around 天安门'

  let(:seller) { create(:seller, :approved, store: store) }
  let(:headers) { api_key_headers.merge('X-Spree-Seller-Id' => seller.prefixed_id) }

  def request_coverage
    get '/api/v3/store/site/coverage', headers: headers
  end

  def codes
    response.parsed_body['data'].map { |division| division['code'] }
  end

  it 'answers the divisions the seller is bound to' do
    create(:stock_location, seller: seller, store: store, administrative_division: dongcheng)
    create(:stock_location, seller: seller, store: store, administrative_division: beijing)

    request_coverage

    expect(response).to have_http_status(:ok)
    expect(codes).to contain_exactly('110000', '110101')
  end

  it 'answers with what is bound and active, not with what used to be' do
    create(:stock_location, seller: seller, store: store, administrative_division: dongcheng)
    create(:stock_location, seller: seller, store: store, administrative_division: beijing, active: false)

    request_coverage

    expect(codes).to eq(%w[110101])
  end

  it 'leaves out a warehouse that was deactivated' do
    create(:stock_location, seller: seller, store: store, administrative_division: dongcheng, active: false)

    request_coverage

    expect(response.parsed_body['data']).to be_empty
  end

  it 'answers nothing for a seller who has bound nothing yet' do
    request_coverage

    expect(response.parsed_body['data']).to be_empty
  end

  it 'refuses a request that named no site' do
    get '/api/v3/store/site/coverage', headers: api_key_headers

    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body['error']['code']).to eq('seller_not_found')
  end
end
