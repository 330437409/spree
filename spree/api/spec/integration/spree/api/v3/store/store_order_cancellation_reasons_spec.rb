# frozen_string_literal: true

# Named to sort late among its neighbours on purpose: the integration suite's
# FactoryBot sequences run process-wide, so a spec that creates records shifts
# every recorded example that runs after it and the checked-in spec carries the
# drift. See spec/support/deterministic_openapi.rb.

require 'swagger_helper'

RSpec.describe 'Order Cancellation Reasons API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  # A retired reason stays on the orders that already carry it, which is what
  # reporting needs, without being handed to another customer.
  let!(:in_use) { create(:order_cancellation_reason, store: store, name: 'Changed my mind') }
  let!(:retired) { create(:order_cancellation_reason, store: store, name: 'Duplicate order', active: false) }

  path '/api/v3/store/order_cancellation_reasons' do
    get 'List the merchant’s reasons for calling an order off' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        The merchant's own vocabulary for why an order was called off, for a customer
        picking one when they cancel an order of their own. Only the reasons still in use
        are listed — a retired one stays on the orders that already carry it without being
        offered again.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true

      response '200', 'the reasons in use' do
        let(:'x-spree-api-key') { api_key.token }

        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: Spree::Api::OpenAPI::SchemaHelper.ref('StoreOrderCancellationReason')
                 }
               },
               required: %w[data]

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].map { |reason| reason['name'] }).to eq(['Changed my mind'])
        end
      end
    end
  end
end
