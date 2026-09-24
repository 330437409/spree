require 'spec_helper'

RSpec.describe 'POST /api/v3/store/scenario_orders', type: :request do
  include_context 'API v3 Store authenticated'

  let(:payment_method) { create(:bogus_payment_method, store: store) }

  before do
    stub_const('SpreeScenarioPurchases::CHANNELS', { 'wechat' => payment_method.type })
  end

  def buy(headers_override: headers, **params)
    post '/api/v3/store/scenario_orders', headers: headers_override,
         params: { kind: 'simple', context: { amount: 30 } }.merge(params)
  end

  it 'buys it and answers the session the client pays through' do
    payment_method

    buy(code: 'auth-code')

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include('kind' => 'simple', 'status' => 'paying', 'amount' => '30.0')
    expect(response.parsed_body['payment_session']).
      to include('external_data' => hash_including('code' => 'auth-code', 'scene' => 'mini_program'))
  end

  # The purchase belongs to whoever made it, so a guest cannot make one.
  it 'requires a signed-in customer' do
    buy(headers_override: api_key_headers)

    expect(response).to have_http_status(:unauthorized)
  end

  it 'refuses a kind this store does not sell, and says so' do
    buy(kind: 'lottery')

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']['message']).to match(/does not sell that/i)
  end

  it 'refuses a kind that will not sell to this customer' do
    buy(kind: 'never')

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']['message']).to match(/cannot buy this yet/i)
  end
end

RSpec.describe 'GET /api/v3/store/customers/me/scenario_orders', type: :request do
  include_context 'API v3 Store authenticated'

  def mine(**params)
    get '/api/v3/store/customers/me/scenario_orders', headers: headers, params: params
  end

  it 'answers the customer\'s own purchases, newest first' do
    first = create(:scenario_order, store: store, customer: user, created_at: 2.hours.ago)
    second = create(:scenario_order, store: store, customer: user)
    create(:scenario_order, store: store, customer: create(:customer))

    mine

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['data'].map { |row| row['id'] }).to eq([second.prefixed_id, first.prefixed_id])
    expect(response.parsed_body['meta']['count']).to eq(2)
  end

  it 'narrows to what is still open' do
    create(:scenario_order, store: store, customer: user, status: 'paying')
    create(:scenario_order, store: store, customer: user, status: 'paid')
    create(:scenario_order, store: store, customer: user, status: 'canceled')

    mine(status: 'open')
    expect(response.parsed_body['data'].map { |row| row['status'] }).to eq(['paying'])

    mine(status: 'paid')
    expect(response.parsed_body['data'].map { |row| row['status'] }).to eq(['paid'])
  end

  # What a plan that sells something here reads back as its own history: this
  # list narrowed to the kind it registered.
  it 'narrows to one kind of purchase' do
    create(:scenario_order, store: store, customer: user, kind: 'never')
    create(:scenario_order, store: store, customer: user, kind: 'simple')

    mine(kind: 'simple')

    expect(response.parsed_body['data'].map { |row| row['kind'] }).to eq(['simple'])
  end
end

RSpec.describe 'the purchase itself', type: :request do
  include_context 'API v3 Store authenticated'

  let(:scenario_order) { create(:scenario_order, store: store, customer: user) }

  it 'answers one purchase' do
    get "/api/v3/store/scenario_orders/#{scenario_order.prefixed_id}", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['kind']).to eq('simple')
  end

  it 'answers 404 for a purchase that belongs to somebody else' do
    other = create(:scenario_order, store: store, customer: create(:customer))

    get "/api/v3/store/scenario_orders/#{other.prefixed_id}", headers: headers

    expect(response).to have_http_status(:not_found)
  end

  it 'calls one off' do
    post "/api/v3/store/scenario_orders/#{scenario_order.prefixed_id}/cancellation", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['status']).to eq('canceled')
    expect(scenario_order.reload).to be_canceled
  end

  it 'removes one from the customer\'s own list' do
    delete "/api/v3/store/scenario_orders/#{scenario_order.prefixed_id}", headers: headers

    expect(response).to have_http_status(:no_content)
    expect(Spree::ScenarioOrder.for_customer(user)).to be_empty
  end

  # What was bought has been handed over, and the row is the record of it.
  it 'keeps a settled purchase in the history' do
    scenario_order.update!(status: 'paid')

    delete "/api/v3/store/scenario_orders/#{scenario_order.prefixed_id}", headers: headers

    expect(response).not_to have_http_status(:no_content)
    expect(Spree::ScenarioOrder.for_customer(user)).to contain_exactly(scenario_order)
  end
end
