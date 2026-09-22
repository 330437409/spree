require 'spec_helper'

RSpec.describe 'GET /api/v3/store/pay_config', type: :request do
  include_context 'API v3 Store guest'

  let(:payment_method) { create(:bogus_payment_method, store: store) }

  before do
    stub_const('SpreeScenarioPurchases::CHANNELS', { 'wechat' => payment_method.type, 'chinaums' => nil })
  end

  it 'answers the channels with a gateway behind them, and what the kinds sell' do
    payment_method

    get '/api/v3/store/pay_config', headers: api_key_headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['channels']).to eq([{ 'channel' => 'wechat' }])
    expect(response.parsed_body['kinds'].map { |kind| kind['kind'] }).to include('simple')
    expect(response.parsed_body['payment_pin']).to be(false)
  end

  # A channel named without a gateway is a column value, not a way to pay.
  it 'answers no channel the store cannot take money in' do
    stub_const('SpreeScenarioPurchases::CHANNELS', { 'wechat' => 'Spree::Gateway::NeverInstalled' })

    get '/api/v3/store/pay_config', headers: api_key_headers

    expect(response.parsed_body['channels']).to be_empty
  end
end
