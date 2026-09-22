require 'spec_helper'

RSpec.describe 'GET /api/v3/store/customers/me/point_accounts/:kind/transactions', type: :request do
  include_context 'API v3 Store authenticated'

  let(:reason) { create(:point_reason, store: store, key: 'consume', label: '消费获赠') }
  let(:account) { create(:point_account, store: store, customer: user, kind: 'points') }

  def history(**params)
    get "/api/v3/store/customers/me/point_accounts/#{params.delete(:kind) || 'points'}/transactions",
        headers: headers, params: params
  end

  before do
    Spree::Points::Ledger.credit!(account: account, amount: 100, reason: reason, idempotency_key: 'lot:1')
    Spree::Points::Ledger.debit!(account: account, amount: 40, reason: reason, idempotency_key: 'spend:1')
  end

  it 'answers the movements, newest first, with the operator’s label' do
    history

    expect(response).to have_http_status(:ok)
    rows = response.parsed_body['data']
    expect(rows.length).to eq(2)
    expect(rows.map { |row| row['amount'] }).to eq(%w[-40.0 100.0])
    expect(rows.first['label']).to eq('消费获赠')
    expect(rows.first['balance_after']).to eq('60.0')
    expect(rows.first['occurred_at']).to be_present
  end

  # The client names the two directions 收入 (`income`) and 支出 (`revenue`),
  # and reads 全部 as no filter at all.
  it 'filters by the client’s own names' do
    history(filter: 'income')
    expect(response.parsed_body['data'].map { |row| row['amount'] }).to eq(%w[100.0])

    history(filter: 'revenue')
    expect(response.parsed_body['data'].map { |row| row['amount'] }).to eq(%w[-40.0])
  end

  it 'reads a key the operator’s list does not hold as itself' do
    Spree::Points::Ledger.credit!(account: account, amount: 5, reason: 'review_reward',
                                  idempotency_key: 'review:1')

    history

    row = response.parsed_body['data'].first
    expect(row['kind']).to eq('review_reward')
    expect(row['label']).to eq('review_reward')
  end

  it 'answers the growth value history at the same route' do
    growth = create(:point_account, store: store, customer: user, kind: 'growth_value')
    Spree::Points::Ledger.credit!(account: growth, amount: 12, reason: reason, idempotency_key: 'vip:1')

    history(kind: 'growth_value')

    expect(response.parsed_body['data'].map { |row| row['amount'] }).to eq(%w[12.0])
  end

  it 'answers 404 for a balance this customer does not hold' do
    history(kind: 'wine_value')

    expect(response).to have_http_status(:not_found)
  end

  it 'refuses a guest' do
    get '/api/v3/store/customers/me/point_accounts/points/transactions', headers: api_key_headers

    expect(response).to have_http_status(:unauthorized)
  end
end
