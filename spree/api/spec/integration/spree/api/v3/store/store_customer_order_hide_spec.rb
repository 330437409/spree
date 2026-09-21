# frozen_string_literal: true

# Named to sort late among its neighbours on purpose: the integration suite's
# FactoryBot sequences run process-wide, so a spec that creates records shifts
# every recorded example that runs after it and the checked-in spec carries the
# drift. See spec/support/deterministic_openapi.rb.

require 'swagger_helper'

RSpec.describe 'Customer Order Hiding API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:order) { create(:completed_order_with_totals, store: store, customer: user) }
  let(:id) { order.prefixed_id }

  path '/api/v3/store/customers/me/orders/{id}' do
    delete 'Hide an order from the customer’s own list' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Takes the order off the customer’s own list. Nothing is deleted: the order stays for
        the merchant, with fulfillment, refunds and reporting untouched. Hiding removes it
        from the customer’s side of their orders — the list and a lookup by id alike — and
        there is no un-hide, so this answers to the shape a delete has.
      DESC

      sdk_example 'customer-orders/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true,
                description: 'Bearer token for the signed-in customer'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Order prefixed ID (e.g., or_abc123)'

      response '204', 'order hidden' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        run_test! do
          expect(order.reload.customer_hidden_at).to be_present
        end
      end

      response '404', 'order belongs to another customer' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { create(:completed_order_with_totals, store: store).prefixed_id }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
