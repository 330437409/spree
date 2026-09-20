# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Customer Purchase History API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:customer) { create(:user_with_addresses) }
  let(:user) { customer }

  let(:frequent_product) { create(:product, store: store, status: 'active') }
  let(:recent_product) { create(:product, store: store, status: 'active') }

  # A completed order carrying one product, dated so the two orderings can be
  # told apart: the product bought often is the one bought longest ago.
  def purchased(product, completed_at:)
    order = create(:order, store: store, customer: customer, completed_at: completed_at)
    create(:line_item, order: order, variant: product.default_variant, quantity: 1, price: 10)
    order
  end

  path '/api/v3/store/customers/me/purchase_history' do
    get 'List purchased products' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        The products the authenticated customer has already bought, for the shelves a
        storefront builds from their own history: ordered by when they bought it
        (`sort=recent`, the default) or by how often they did (`sort=frequent`).

        Only products the store still sells are answered, and a product bought from
        another store, or in an order that was never completed, is not part of it.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Ordering of the history: recent (default, most recently bought first) or frequent (bought most often first)'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number (default: 1)'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of results per page (default: 25, max: 100)'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (variants, media, option_values)'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., name,slug,price). id is always included.'

      response '200', 'the products this customer bought, most recent first' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        before do
          3.times { |i| purchased(frequent_product, completed_at: (10 + i).days.ago) }
          purchased(recent_product, completed_at: 1.hour.ago)

          # Another shopper's history is not this one's.
          create(:line_item,
                 order: create(:order, store: store, customer: create(:user_with_addresses), completed_at: 1.hour.ago),
                 variant: create(:product, store: store, status: 'active').default_variant,
                 quantity: 1, price: 10)
        end

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Product' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               },
               required: %w[data meta]

        run_test! do |response|
          data = JSON.parse(response.body)

          expect(data['data'].map { |row| row['id'] }).to eq([recent_product.prefixed_id, frequent_product.prefixed_id])
          expect(data['meta']['count']).to eq(2)
        end
      end

      response '200', 'the products bought most often, first' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:sort) { 'frequent' }

        before do
          3.times { |i| purchased(frequent_product, completed_at: (10 + i).days.ago) }
          purchased(recent_product, completed_at: 1.hour.ago)
        end

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Product' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               },
               required: %w[data meta]

        run_test! do |response|
          data = JSON.parse(response.body)

          expect(data['data'].first['id']).to eq(frequent_product.prefixed_id)
        end
      end

      response '422', 'an ordering that does not exist' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:sort) { 'cheapest' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { '' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
