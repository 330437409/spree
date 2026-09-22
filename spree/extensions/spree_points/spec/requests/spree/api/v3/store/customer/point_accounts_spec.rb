require 'spec_helper'

RSpec.describe 'GET /api/v3/store/customers/me/point_accounts', type: :request do
  include_context 'API v3 Store authenticated'

  let(:reason) { create(:point_reason, store: store, key: 'consume', label: '消费获赠') }

  def get_accounts(headers_override = headers)
    get '/api/v3/store/customers/me/point_accounts', headers: headers_override
  end

  it 'answers both balances, zero where nothing has moved' do
    get_accounts

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['data'].map { |row| row['kind'] }).to eq(%w[points growth_value])
    expect(response.parsed_body['data'].map { |row| row['balance'] }).to eq([0, 0])
  end

  it 'answers the balance with what is about to lapse and the two rates' do
    account = create(:point_account, store: store, customer: user, kind: 'points')
    Spree::Points::Ledger.credit!(account: account, amount: 30, reason: reason, idempotency_key: 'lot:1',
                                  expires_at: 3.days.from_now)

    get_accounts

    row = response.parsed_body['data'].find { |entry| entry['kind'] == 'points' }
    expect(row['balance']).to eq(30)
    expect(row['lifetime_earned']).to eq(30)
    expect(row['expiring_total']).to eq(30)
    expect(row['expires_at']).to be_present
    expect(row['earn_rate']).to eq('1.0')
    expect(row['redeem_rate']).to eq('100.0')
  end

  # 成长值 does not lapse, and a zero would say "nothing is expiring yet",
  # which is a different statement.
  it 'answers a null expiry on the balance that never lapses' do
    account = create(:point_account, store: store, customer: user, kind: 'growth_value')
    Spree::Points::Ledger.credit!(account: account, amount: 12, reason: reason, idempotency_key: 'vip:1')

    get_accounts

    row = response.parsed_body['data'].find { |entry| entry['kind'] == 'growth_value' }
    expect(row['balance']).to eq(12)
    expect(row['expiring_total']).to be_nil
    expect(row['expires_at']).to be_nil
  end

  it 'answers only this customer’s balances' do
    other = create(:point_account, store: store, customer: create(:customer))
    Spree::Points::Ledger.credit!(account: other, amount: 99, reason: reason, idempotency_key: 'their:lot')

    get_accounts

    expect(response.parsed_body['data'].map { |row| row['balance'] }).to eq([0, 0])
  end

  it 'refuses a guest' do
    get_accounts(api_key_headers)

    expect(response).to have_http_status(:unauthorized)
  end
end
