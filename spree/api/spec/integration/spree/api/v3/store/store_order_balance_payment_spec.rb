# frozen_string_literal: true

# Named to sort late among its neighbours on purpose: the integration suite's
# FactoryBot sequences run process-wide, so a spec that creates records shifts
# every recorded example that runs after it and the checked-in spec carries the
# drift. See spec/support/deterministic_openapi.rb.

require 'swagger_helper'

# Events on: the order's rollup after a capture is the OrderStatusSubscriber's
# work, and specs run with the bus off.
RSpec.describe 'Order Balance Payment API', type: :request, swagger_doc: 'api-reference/store.yaml', events: true do
  include_context 'API v3 Store'

  let!(:order) { create(:completed_order_with_totals, store: store, customer: user) }
  let!(:credit) { create(:store_credit, customer: user, store: store, amount: order.total) }
  let(:order_id) { order.prefixed_id }

  before { create(:store_credit_payment_method, store: store) }

  path '/api/v3/store/customers/me/orders/{order_id}/store_credits' do
    post 'Pay an order from the customer’s own balance' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Settles what the order still owes from the customer's stored value — the balance
        payment an unpaid order offers. It is all or nothing: a balance that covers only part
        of the order is refused, with the shortfall named in the message, because a partially
        paid order would otherwise answer as if it were paid while the rest is still owed.

        The balance is spent through the store credit apply service — where the payment PIN
        is consulted — and what it applies is captured in the same call, because an order is
        paid rather than reserved. A canceled order, or one that owes nothing, is refused.
      DESC

      sdk_example 'customer-orders/store-credits-apply'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true,
                description: 'Bearer token for the signed-in customer'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order prefixed ID (e.g., or_abc123)'

      response '200', 'the order, paid from the balance' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        schema '$ref' => '#/components/schemas/Order'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['payment_status']).to eq('paid')
          expect(data['amount_due'].to_f).to eq(0)
        end
      end

      response '422', 'a balance that does not cover the order' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        # The customer's whole balance, across every credit they hold, falls short.
        let!(:credit) { create(:store_credit, customer: user, store: store, amount: order.total - 1) }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          expect(JSON.parse(response.body)['error']['message']).to include('does not cover')
        end
      end
    end
  end
end
