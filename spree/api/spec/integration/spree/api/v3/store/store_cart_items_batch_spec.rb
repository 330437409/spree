# frozen_string_literal: true

# Named to sort late among its neighbours on purpose: the integration suite's
# FactoryBot sequences run process-wide, so a spec that creates records shifts
# every recorded example that runs after it and the checked-in spec carries the
# drift. See spec/support/deterministic_openapi.rb.

require 'swagger_helper'

RSpec.describe 'Cart Items Batch API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:order) { create(:cart, store: store, customer: user) }
  let!(:product) { create(:product, store: store) }
  let!(:variant) { create(:variant, product: product, price: 10) }
  let(:cart_id) { order.prefixed_id }

  path '/api/v3/store/carts/{cart_id}/items/batch' do
    post 'Write a set of lines in one request' do
      tags 'Carts'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Writes a set of the cart's lines in one pass: the quantities named are the ones the
        cart should end up holding, so a retried request writes the same cart rather than
        adding twice. An entry names either the variant to buy or a line of this cart, and
        the whole set recalculates once.

        A set is not all-or-nothing: an entry the cart's rules refuse (out of stock, an
        unsellable currency) comes back in the cart's `warnings` and the rest of the set
        applies. A request that cannot be applied at all — an empty set, a quantity that is
        not a positive whole number, a line this cart does not hold — is refused whole.
      DESC

      sdk_example 'carts/items-batch'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer token for authenticated customers'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false,
                description: 'Cart token for guest access'
      parameter name: :cart_id, in: :path, type: :string, required: true,
                description: 'Cart prefixed ID (e.g., cart_abc123)'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          items: {
            type: :array,
            description: 'The lines to write',
            items: {
              type: :object,
              properties: {
                variant_id: { type: :string, example: 'variant_abc123',
                              description: 'The variant to buy' },
                line_item_id: { type: :string, example: 'li_abc123',
                                description: 'A line of this cart to write; takes precedence over variant_id' },
                quantity: { type: :integer, example: 2,
                            description: 'The quantity the line should hold (default: 1)' },
                metadata: { type: :object, additionalProperties: true,
                            description: 'Arbitrary key-value metadata for the line' }
              }
            }
          }
        },
        required: %w[items]
      }

      response '201', 'the cart, with the set written' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { items: [{ variant_id: variant.prefixed_id, quantity: 2 }] } }

        schema '$ref' => '#/components/schemas/Cart'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['items'].first['quantity']).to eq(2)
          expect(data['total_quantity']).to eq(2)
        end
      end

      response '422', 'the set names no item' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { items: [] } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          expect(JSON.parse(response.body)['error']['code']).to eq('validation_error')
        end
      end
    end
  end
end
