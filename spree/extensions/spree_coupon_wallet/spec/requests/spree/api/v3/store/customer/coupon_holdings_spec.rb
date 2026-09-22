require 'spec_helper'

RSpec.describe 'GET /api/v3/store/customers/me/coupon_holdings', type: :request do
  include_context 'API v3 Store authenticated'

  def issue(customer: user, **overrides)
    promotion = overrides.delete(:promotion) || create(:coupon_wallet_promotion, store: store)

    Spree::Coupons::Issue.call(
      promotion: promotion, customer: customer, source: 'admin', store: store,
      idempotency_key: "spec:#{SecureRandom.hex(6)}", **overrides
    ).value
  end

  def wallet(**params)
    get '/api/v3/store/customers/me/coupon_holdings', headers: headers, params: params
  end

  it 'answers the coupons the customer holds, newest first, with what they are worth' do
    first = issue
    second = issue

    wallet

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['data'].map { |row| row['code'] }).to eq([second.code, first.code])
    expect(response.parsed_body['data'].first).to include('status' => 'unused', 'source' => 'admin')
    expect(response.parsed_body['data'].first['promotion']).
      to include('name' => second.coupon_code.promotion.name)
    expect(response.parsed_body['meta']['count']).to eq(2)
  end

  it 'answers only the customer’s own coupons' do
    issue(customer: create(:customer))

    wallet

    expect(response.parsed_body['data']).to be_empty
  end

  describe 'its tabs' do
    it 'separates what is spent, what has lapsed and what is still usable' do
      spent = issue
      spent.coupon_code.update!(state: 'used')
      lapsed = issue
      lapsed.grant.update!(expires_at: 1.day.ago)
      usable = issue

      expect(codes_for(status: 'used')).to eq([spent.code])
      expect(codes_for(status: 'expired')).to eq([lapsed.code])
      expect(codes_for(status: 'unused')).to eq([usable.code])
      expect(codes_for(status: 'everything')).to contain_exactly(spent.code, lapsed.code, usable.code)
    end

    it 'answers what lapses before a day the customer names' do
      soon = issue(expires_at: 3.days.from_now)
      issue(expires_at: 60.days.from_now)

      expect(codes_for(status: 'expiring', expires_before: 10.days.from_now.to_date.iso8601)).to eq([soon.code])
    end
  end

  it 'requires a signed-in customer' do
    get '/api/v3/store/customers/me/coupon_holdings', headers: api_key_headers

    expect(response).to have_http_status(:unauthorized)
  end

  def codes_for(**params)
    wallet(**params)
    response.parsed_body['data'].map { |row| row['code'] }
  end
end

RSpec.describe 'GET /api/v3/store/customers/me/coupon_holdings/:id', type: :request do
  include_context 'API v3 Store authenticated'

  let(:holding) do
    Spree::Coupons::Issue.call(
      promotion: create(:coupon_wallet_promotion, store: store), customer: user,
      source: 'admin', store: store, idempotency_key: 'spec:one'
    ).value
  end

  it 'answers one coupon' do
    get "/api/v3/store/customers/me/coupon_holdings/#{holding.prefixed_id}", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('code' => holding.code, 'status' => 'unused')
  end

  it 'answers 404 for a coupon that belongs to somebody else' do
    other = Spree::Coupons::Issue.call(
      promotion: create(:coupon_wallet_promotion, store: store), customer: create(:customer),
      source: 'admin', store: store, idempotency_key: 'spec:other'
    ).value

    get "/api/v3/store/customers/me/coupon_holdings/#{other.prefixed_id}", headers: headers

    expect(response).to have_http_status(:not_found)
  end
end

RSpec.describe 'POST /api/v3/store/customers/me/coupon_holdings', type: :request do
  include_context 'API v3 Store authenticated'

  let(:promotion) { create(:coupon_wallet_promotion, store: store) }
  let(:code) { promotion.coupon_codes.first.code }

  # `self.` reads the example's own code: a bare `code` in a default is the
  # parameter being defined, not the `let`.
  def claim(code: self.code, headers_override: headers)
    post '/api/v3/store/customers/me/coupon_holdings', headers: headers_override, params: { code: code }
  end

  it 'claims a code the customer was sent into their wallet' do
    claim

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include('code' => code.upcase, 'status' => 'unused')
    expect(Spree::CouponHolding.for_customer(user).count).to eq(1)
  end

  it 'ignores the case and the spaces a customer types' do
    claim(code: "  #{code.upcase} ")

    expect(response).to have_http_status(:created)
  end

  it 'answers the same coupon when the code arrives twice' do
    claim
    first = response.parsed_body['code']
    claim

    expect(response.parsed_body['code']).to eq(first)
    expect(Spree::CouponHolding.count).to eq(1)
  end

  it 'refuses a code nobody issued, and says so' do
    claim(code: 'nope-0000')

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']['message']).to match(/could not find that coupon code/i)
  end

  it 'refuses a code somebody else already holds' do
    claim
    other = create(:customer)
    other_headers = api_key_headers.merge(
      'Authorization' => "Bearer #{Spree::Api::V3::TestingSupport.generate_jwt(other)}"
    )

    claim(headers_override: other_headers)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']['message']).to match(/belongs to somebody else/i)
  end

  it 'requires a signed-in customer' do
    claim(headers_override: api_key_headers)

    expect(response).to have_http_status(:unauthorized)
  end
end
