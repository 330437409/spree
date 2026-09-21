# frozen_string_literal: true

# Named to sort late among its neighbours on purpose: the integration suite's
# FactoryBot sequences run process-wide, so a spec that creates records shifts
# every recorded example that runs after it and the checked-in spec carries the
# drift. See spec/support/deterministic_openapi.rb.

require 'swagger_helper'

RSpec.describe 'Order Cancellation API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:order) { create(:completed_order_with_totals, store: store, customer: user) }
  let!(:reason) { create(:order_cancellation_reason, store: store, name: 'Changed my mind') }
  let(:order_id) { order.prefixed_id }

  path '/api/v3/store/customers/me/orders/{order_id}/cancellation' do
    post 'Call off one of the customer’s own orders' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        A customer calling off their own order. It is creating a cancellation rather than
        performing a cancel action: one act, happening once, whose result is the order in
        its canceled state — which is what the response carries, with `cancellable` now
        false.

        Whether an order can still be called off is decided when the write arrives, not by
        the button: an order whose parcel has been dispatched is refused. The list a
        customer picks their reason from is `GET /order_cancellation_reasons`.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true,
                description: 'Bearer token for the signed-in customer'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order prefixed ID (e.g., or_abc123)'
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: {
          reason_id: { type: :string, example: 'ocr_abc123',
                       description: 'One of the store’s cancellation reasons, from the reasons read' },
          note: { type: :string, example: 'Found it cheaper elsewhere',
                  description: 'What the customer said, kept on the order beside the reason' }
        }
      }

      response '200', 'the order, called off' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { reason_id: reason.prefixed_id, note: 'Found it cheaper elsewhere' } }

        schema '$ref' => '#/components/schemas/Order'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('canceled')
          expect(data['cancellable']).to be(false)
        end
      end

      response '422', 'an order that can no longer be called off' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) do
          create(:completed_order_with_totals, store: store, customer: user).
            tap { |record| record.update_columns(fulfillment_status: 'shipped') }.
            prefixed_id
        end

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          expect(JSON.parse(response.body)['error']).to be_present
        end
      end
    end
  end
end
