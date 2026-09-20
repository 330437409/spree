# frozen_string_literal: true

# Named to sort late among its neighbours on purpose: the integration suite's
# FactoryBot sequences run process-wide, so a spec that creates records shifts
# every recorded example that runs after it and the checked-in spec carries the
# drift. See spec/support/deterministic_openapi.rb.

require 'swagger_helper'

RSpec.describe 'Cart Count API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:order) { create(:cart, store: store, customer: user) }
  let!(:product) { create(:product) }
  let(:cart_id) { order.prefixed_id }

  before do
    Spree::Carts::AddItem.call(cart: order, variant: product.default_variant, quantity: 2)
  end

  path '/api/v3/store/carts/{cart_id}/count' do
    get 'Get a cart’s item counts' do
      tags 'Carts'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        How much is in the cart, without reading the cart: the units it holds and how many
        of them the shopper has ticked for checkout. The two figures are the cart payload's
        own — `total_quantity` and `selected_quantity` — for a storefront that renders a
        badge on pages with no other business with the cart.
      DESC

      sdk_example 'carts/count'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer token for authenticated customers'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false,
                description: 'Cart token for guest access'
      parameter name: :cart_id, in: :path, type: :string, required: true,
                description: 'Cart prefixed ID (e.g., cart_abc123)'

      response '200', 'the cart’s item counts' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        schema '$ref' => '#/components/schemas/CartCount'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(order.prefixed_id)
          expect(data['total_quantity']).to eq(2)
          expect(data['selected_quantity']).to eq(2)
          expect(data).not_to have_key('items')
        end
      end

      response '404', 'the cart is not one this store holds' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:cart_id) { create(:cart, store: create(:store)).prefixed_id }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
