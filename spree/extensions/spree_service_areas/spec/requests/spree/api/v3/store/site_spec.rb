require 'spec_helper'

RSpec.describe 'GET /api/v3/store/site', type: :request do
  include_context 'API v3 Store'

  # A slug of its own: the model derives one from the name, and a Chinese name
  # parameterises to nothing — which the seller-join form will have to answer
  # for separately (a seller cannot be onboarded without one today).
  let(:seller) do
    create(:seller, :approved, store: store, name: '南山区水果店', slug: 'nanshan-fruit',
                              legal_name: '深圳南山区水果有限公司',
                              site_svip: true, business_model: 'franchise')
  end
  let(:headers) { api_key_headers.merge('X-Spree-Seller-Id' => seller.prefixed_id) }

  def request_site(overrides = {})
    get '/api/v3/store/site', headers: headers.merge(overrides)
  end

  it 'answers the site the request named' do
    request_site

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include(
      'id' => seller.prefixed_id, 'name' => '南山区水果店', 'slug' => seller.slug
    )
    expect(response.parsed_body['site_svip']).to be true
  end

  it 'carries the seller profile the seller surface carries, because it is the same profile' do
    request_site

    expect(response.parsed_body.keys).to include('about', 'logo_url', 'square_logo_url', 'cover_photo_url')
  end

  it 'describes how the shop is operated' do
    request_site

    expect(response.parsed_body['operator']).to include(
      'id' => seller.prefixed_id,
      'site_name' => '南山区水果店',
      'company_name' => '深圳南山区水果有限公司',
      'business_model' => 'franchise'
    )
  end

  it 'answers a shopper who is not signed in' do
    request_site

    expect(response).to have_http_status(:ok)
  end

  it 'says a site that sells no memberships does not' do
    seller.update!(site_svip: false)

    request_site

    expect(response.parsed_body['site_svip']).to be false
  end

  it 'accepts the slug a storefront links with, not only the id' do
    request_site('X-Spree-Seller-Id' => seller.slug)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['id']).to eq(seller.prefixed_id)
  end

  describe 'refusals' do
    it 'refuses a request that named no site, and says which call settles it' do
      get '/api/v3/store/site', headers: api_key_headers

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['error']['code']).to eq('seller_not_found')
      expect(response.parsed_body['error']['message']).to match(/did not name a site/)
    end

    it 'refuses a site this store does not have' do
      request_site('X-Spree-Seller-Id' => 'sel_does_not_exist')

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['error']['code']).to eq('seller_not_found')
    end

    it 'refuses a request with no publishable key' do
      get '/api/v3/store/site', headers: { 'X-Spree-Seller-Id' => seller.prefixed_id }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
