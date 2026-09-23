require 'spec_helper'

RSpec.describe 'buying a term', type: :request do
  include_context 'API v3 Store authenticated'

  let(:payment_method) { create(:bogus_payment_method, store: store) }
  let(:group) { create(:customer_group, store: store) }
  let(:tier) do
    create(:membership_tier_setting, customer_group: group, rank: 1, validity_days: 365, sku: 'VIP-365')
  end

  before do
    stub_const('SpreeScenarioPurchases::CHANNELS', { 'wechat' => payment_method.type })
    tier
    create(:variant, product: create(:product, store: store), sku: 'VIP-365', price: 365)
  end

  def buy(**context)
    post '/api/v3/store/scenario_orders', headers: headers,
         params: { kind: 'vip', context: { tier_id: tier.prefixed_id }.merge(context) }
  end

  # One call buys it — no cart, no line item, no address — and settling it issues
  # the card, which is the whole of what this kind hands over.
  it 'issues a dormant card once the purchase is paid' do
    buy(purpose: 'gift')

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include('kind' => 'vip', 'status' => 'paying', 'amount' => '365.0')
    expect(response.parsed_body['payload']).to include('purpose' => 'gift')

    purchase = Spree::ScenarioOrder.find_by_prefix_id(response.parsed_body['id'])
    Spree::PaymentSessions::Complete.call(payment_session: purchase.payment_session)
    # What the frame's session-completed subscriber does, called here because the
    # suite disables events.
    Spree::ScenarioOrders::Settle.call(scenario_order: purchase)

    card = Spree::MembershipCard.last
    expect(card).to be_dormant
    expect(card.customer).to eq(user)
    expect(card.customer_group).to eq(group)
    expect(card.source).to eq('purchase')
    expect(card.scenario_order.reload).to be_paid
  end

  it 'refuses a package that is not for sale' do
    tier.update!(sku: nil)

    buy

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']['message']).to match(/sale/i)
    expect(Spree::ScenarioOrder.count).to eq(0)
  end

  # What the buy page renders: the packages this store sells, at the price it
  # sells them for.
  it 'lists the packages on sale in the pay config' do
    get '/api/v3/store/pay_config', headers: api_key_headers

    offer = response.parsed_body['kinds'].find { |kind| kind['kind'] == 'vip' }

    expect(offer['offers']).to contain_exactly(
      include('tier_id' => tier.prefixed_id, 'amount' => '365.0', 'currency' => 'USD')
    )
  end
end
