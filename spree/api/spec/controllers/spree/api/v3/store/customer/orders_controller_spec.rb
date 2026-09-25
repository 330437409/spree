require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Customer::OrdersController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:order) { create(:completed_order_with_totals, customer: user, store: store) }
  let!(:other_user_order) { create(:completed_order_with_totals, store: store) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'GET #index' do
    it 'returns user orders' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(1)
      expect(json_response['data'].first['number']).to eq(order.number)
    end

    it 'does not return other users orders' do
      get :index

      numbers = json_response['data'].map { |o| o['number'] }
      expect(numbers).not_to include(other_user_order.number)
    end

    it 'does not return orders from other stores' do
      other_store = create(:store)
      create(:completed_order_with_totals, customer: user, store: other_store)

      get :index

      numbers = json_response['data'].map { |o| o['number'] }
      expect(numbers).to eq([order.number])
    end

    # Filters are yes/no questions: one that could follow the order into its
    # promotions, or test the email, would answer about data the customer
    # never sees (another shopper's unused coupon codes, staff fields).
    it 'ignores filters that reach beyond the order itself' do
      get :index, params: { q: { promotions_coupon_codes_code_start: 'zzz', email_start: 'zzz', considered_risky_eq: true, search: 'zzz' } }

      expect(json_response['data'].map { |o| o['number'] }).to eq([order.number])
    end

    it 'still filters on the order itself' do
      get :index, params: { q: { number_eq: 'nope' } }

      expect(json_response['data']).to be_empty
    end

    it 'returns pagination metadata' do
      get :index

      expect(json_response['meta']).to include('page', 'count', 'pages')
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
      end
    end

    context 'when a hidden order is on the account' do
      let!(:hidden_order) do
        create(:completed_order_with_totals, store: store, customer: user).
          tap(&:hide_from_customer!)
      end

      it 'leaves it out of the list' do
        get :index

        numbers = json_response['data'].map { |o| o['number'] }
        expect(numbers).to eq([order.number])
      end

      it 'answers 404 for it, too — the customer’s side of the order is gone' do
        get :show, params: { id: hidden_order.prefixed_id }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'takes the order off the customer’s list, leaving the row for the merchant' do
      delete :destroy, params: { id: order.prefixed_id }

      expect(response).to have_http_status(:no_content)
      expect(order.reload.customer_hidden_at).to be_present
      expect(order.completed_at).to be_present
    end

    it 'leaves the order in the merchant’s own scope' do
      delete :destroy, params: { id: order.prefixed_id }

      expect(Spree::Order.for_store(store)).to include(order.reload)
    end

    it 'answers 404 for an order that is not theirs' do
      delete :destroy, params: { id: other_user_order.prefixed_id }

      expect(response).to have_http_status(:not_found)
      expect(other_user_order.reload.customer_hidden_at).to be_nil
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        delete :destroy, params: { id: order.prefixed_id }

        expect(response).to have_http_status(:unauthorized)
        expect(order.reload.customer_hidden_at).to be_nil
      end
    end
  end
end
