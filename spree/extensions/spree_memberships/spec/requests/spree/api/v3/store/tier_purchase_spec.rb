require 'spec_helper'

RSpec.describe 'buying a term', type: :request do
  include_context 'API v3 Store authenticated'

  include_context 'a priced tier'

  let(:payment_method) { create(:bogus_payment_method, store: store) }

  before { stub_const('SpreeScenarioPurchases::CHANNELS', { 'wechat' => payment_method.type }) }

  def buy(**context)
    post '/api/v3/store/scenario_orders', headers: headers,
         params: { kind: 'vip', context: { tier_id: tier.prefixed_id }.merge(context) }
  end

  # The purchase the last `buy` made, paid for — which is when the card exists.
  # The frame's session-completed subscriber does this in production, called here
  # because the suite disables events. It makes no request of its own, so the
  # create's response is still the one to read afterwards.
  def settle(**context)
    buy(**context)
    purchase = Spree::ScenarioOrder.find_by_prefix_id(response.parsed_body['id'])
    Spree::PaymentSessions::Complete.call(payment_session: purchase.payment_session)
    Spree::ScenarioOrders::Settle.call(scenario_order: purchase)
    purchase
  end

  # One call buys it — no cart, no line item, no address — and settling it issues
  # the card, which is the whole of what this kind hands over.
  it 'issues a dormant card once the purchase is paid' do
    purchase = settle(purpose: 'gift')

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include('kind' => 'vip', 'status' => 'paying', 'amount' => '365.0')
    expect(response.parsed_body['payload']).to include('purpose' => 'gift')

    card = Spree::MembershipCard.find_by(scenario_order: purchase)
    expect(card).to be_dormant
    expect(card.customer).to eq(user)
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

  # What the client reads back after paying: the gift the purchase released,
  # addressed by the purchase rather than searched for in the wallet.
  describe 'GET /api/v3/store/scenario_orders/:id/membership_card' do
    it 'answers the card the purchase issued' do
      purchase = settle

      get "/api/v3/store/scenario_orders/#{purchase.prefixed_id}/membership_card", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('status' => 'dormant', 'source' => 'purchase')
      expect(response.parsed_body['tier']).to include('id' => tier.prefixed_id, 'rank' => 1)
    end

    it 'answers 404 for a purchase that released nothing yet' do
      buy
      purchase = Spree::ScenarioOrder.find_by_prefix_id(response.parsed_body['id'])

      get "/api/v3/store/scenario_orders/#{purchase.prefixed_id}/membership_card", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    # Read through the customer's own purchases, so somebody else's is not found
    # rather than answered. Their purchase is settled, so it is the purchase's
    # own scope that answers this and not the card's absence.
    it 'answers 404 for a settled purchase that is not theirs' do
      stranger = create(:customer)
      purchase = create(:scenario_order, store: store, customer: stranger, kind: 'vip', status: 'paid')
      create(:membership_card, store: store, customer: stranger, customer_group: group,
                               scenario_order: purchase)

      get "/api/v3/store/scenario_orders/#{purchase.prefixed_id}/membership_card", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    # The caller's own purchase, in another store: the store is the outer scope
    # and the one that answers. The card's own customer is deliberately not
    # asked again — a kind that issued it to somebody else would otherwise leave
    # the buyer answered nothing for what they paid for.
    it 'answers 404 for a purchase of another store' do
      elsewhere = create(:store)
      purchase = create(:scenario_order, store: elsewhere, customer: user, kind: 'vip', status: 'paid')
      create(:membership_card, store: elsewhere, customer: user,
                               customer_group: create(:customer_group, store: elsewhere),
                               scenario_order: purchase)

      get "/api/v3/store/scenario_orders/#{purchase.prefixed_id}/membership_card", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'requires a signed-in customer' do
      purchase = settle

      get "/api/v3/store/scenario_orders/#{purchase.prefixed_id}/membership_card", headers: api_key_headers

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
