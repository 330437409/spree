# frozen_string_literal: true

# Named to sort late among its neighbours on purpose: the integration suite's
# FactoryBot sequences run process-wide, so a spec that creates records shifts
# every recorded example that runs after it and the checked-in spec carries the
# drift. See spec/support/deterministic_openapi.rb.

require 'swagger_helper'

RSpec.describe 'Cart Recommendations API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:cart) { create(:cart, store: store, customer: user) }
  let!(:tea) { create(:line_item, cart: cart, quantity: 1, price: 100) }
  let(:cart_id) { cart.prefixed_id }
  let(:tea_category) { create(:category, store: store, name: 'Tea') }

  before do
    tea.product.categories << tea_category
    create(:product, store: store, name: 'Another tea').categories << tea_category
  end

  path '/api/v3/store/carts/{cart_id}/recommendations' do
    get 'List what else the shopper might want' do
      tags 'Carts'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        A shelf read from what is already in the basket: the categories its goods are in, ranked
        by what sells, with the basket's own goods left out.

        It answers from the storefront's own catalogue, so a recommendation is never a way to see
        something the catalogue would not show, and it asks the store's search provider — a store
        with an index answers from it, a store without one answers from the database.
      DESC

      sdk_example 'carts/recommendations-list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer token for authenticated customers'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false,
                description: 'Cart token for guest access'
      parameter name: :cart_id, in: :path, type: :string, required: true,
                description: 'Cart prefixed ID (e.g., cart_abc123)'
      parameter name: :limit, in: :query, type: :integer, required: false,
                description: 'How many goods to offer (default 12, at most 24)'

      response '200', 'recommendations offered' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'x-spree-token') { cart.token }

        schema type: :object,
               properties: { data: { type: :array, items: { '$ref' => '#/components/schemas/Product' } } },
               required: %w[data]

        run_test! do |response|
          data = JSON.parse(response.body)
          names = data['data'].map { |product| product['name'] }

          expect(names).to include('Another tea')
          expect(names).not_to include(tea.product.name)
        end
      end
    end
  end
end
