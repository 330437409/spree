require 'spec_helper'

RSpec.describe Spree::ScenarioOrders::Create do
  let(:store) { @default_store }
  let(:customer) { create(:customer) }
  let(:payment_method) { create(:bogus_payment_method, store: store) }

  before do
    # A channel names the gateway that takes its money. The frame ships with
    # WeChat Pay and the dummy application has the bogus gateway, so the channel
    # under test points at the one that is here.
    stub_const('SpreeScenarioPurchases::CHANNELS', { 'wechat' => payment_method.type })
  end

  def buy(**overrides)
    described_class.call(
      { kind: 'simple', store: store, customer: customer, channel: 'wechat',
        context: { 'amount' => 25 }, external_data: { 'scene' => 'mini_program' } }.merge(overrides)
    )
  end

  it 'prices it through the kind and opens a session against it' do
    result = buy

    expect(result).to be_success
    order = result.value
    expect(order.amount).to eq(25)
    expect(order).to be_paying
    expect(order.payment_channel).to eq('wechat')
    expect(order.payload).to eq('amount' => 25)
    expect(order.payment_session).to be_present
    expect(order.payment_session.scenario_order).to eq(order)
  end

  it 'refuses a kind nothing registered' do
    expect(buy(kind: 'lottery')).to be_failure
    expect(Spree::ScenarioOrder.count).to eq(0)
  end

  it 'refuses a kind whose own eligibility says no' do
    result = buy(kind: 'never')

    expect(result).to be_failure
    expect(Spree::ScenarioOrder.count).to eq(0)
  end

  # A channel with no gateway behind it is a column value, not a way to pay.
  it 'refuses a channel this store has no gateway for' do
    expect(buy(channel: 'chinaums')).to be_failure
  end

  it 'hands the gateway the scene and the code the customer paid with' do
    result = buy(external_data: { 'scene' => 'jsapi', 'code' => 'auth-code' })

    expect(result.value.payment_session.external_data['scene']).to eq('jsapi')
    expect(result.value.payment_session.external_data['code']).to eq('auth-code')
  end
end
