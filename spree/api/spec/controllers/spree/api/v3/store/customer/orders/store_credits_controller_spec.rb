require 'spec_helper'

# Events on: the order's rollup after a capture is the OrderStatusSubscriber's
# work, and specs run with the bus off.
RSpec.describe Spree::Api::V3::Store::Customer::Orders::StoreCreditsController, type: :controller, events: true do
  render_views

  include_context 'API v3 Store'

  let!(:order) { create(:completed_order_with_totals, store: store, customer: user) }
  let!(:credit) { create(:store_credit, customer: user, store: store, amount: order.total) }

  before do
    create(:store_credit_payment_method, store: store)
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'POST #create' do
    it 'pays the order from the customer’s own balance' do
      post :create, params: { order_id: order.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['payment_status']).to eq('paid')
      expect(order.reload.outstanding_balance).to eq(0)
      expect(credit.reload.amount_remaining).to eq(0)
    end

    it 'refuses a balance that cannot cover the order, naming the shortfall' do
      credit.update_column(:amount, order.total - 1)

      post :create, params: { order_id: order.prefixed_id }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['message']).to include('does not cover')
      expect(order.reload.outstanding_balance).to eq(order.total)
    end

    # Somebody else's order is not one this customer can see, let alone pay.
    it 'answers 404 for an order that is not theirs' do
      someone_elses = create(:completed_order_with_totals, store: store, customer: create(:user))

      post :create, params: { order_id: someone_elses.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end

    it 'does not reach an order of another store' do
      other_store_order = create(:completed_order_with_totals, customer: user, store: create(:store))

      post :create, params: { order_id: other_store_order.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        post :create, params: { order_id: order.prefixed_id }

        expect(response).to have_http_status(:unauthorized)
        expect(order.reload.outstanding_balance).to eq(order.total)
      end
    end

    # The tender's second factor, exercised through the seam rather than
    # through the gem that implements it: this engine must ask whatever is
    # registered, and a deployment that registers nothing must pay as it
    # always did.
    context 'when the tender asks for a second factor' do
      let(:verification) { instance_double(Spree::PaymentVerification) }

      before { allow(Spree).to receive(:payment_verifications).and_return([verification]) }

      it 'gives the proof to the verification before any money moves' do
        allow(verification).to receive(:required?).with(order: order).and_return(true)
        allow(verification).to receive(:verify).with(order: order, proof: '246813').and_return(nil)

        post :create, params: { order_id: order.prefixed_id, pay_password: '246813' }

        expect(response).to have_http_status(:ok)
        expect(order.reload.outstanding_balance).to eq(0)
      end

      it 'refuses the write when it refuses, in its own words and with its own code' do
        allow(verification).to receive(:required?).with(order: order).and_return(true)
        allow(verification).to receive(:verify).and_return(
          Spree::PaymentVerification::Refusal.new(kind: 'invalid', message: 'That payment PIN is not correct.')
        )

        post :create, params: { order_id: order.prefixed_id, pay_password: '999999' }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('payment_pin_invalid')
        expect(json_response['error']['message']).to eq('That payment PIN is not correct.')
        expect(order.reload.outstanding_balance).to eq(order.total)
        expect(credit.reload.amount_remaining).to eq(order.total)
      end

      # The client reads balance_not_password to decide whether to prompt, so
      # a write with no proof is what a client that ignored the flag sends.
      it 'refuses a spend with no proof at all' do
        allow(verification).to receive(:required?).with(order: order).and_return(true)
        allow(verification).to receive(:verify).with(order: order, proof: nil).and_return(
          Spree::PaymentVerification::Refusal.new(kind: 'required', message: 'Enter your payment PIN.')
        )

        post :create, params: { order_id: order.prefixed_id }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('payment_pin_required')
        expect(order.reload.outstanding_balance).to eq(order.total)
      end

      it 'reports the verdict on the order payload, so the client knows to ask' do
        allow(verification).to receive(:required?).with(order: order).and_return(true)
        allow(verification).to receive(:verify).and_return(nil)

        post :create, params: { order_id: order.prefixed_id, pay_password: '246813' }

        expect(json_response['balance_not_password']).to be false
      end
    end
  end
end
