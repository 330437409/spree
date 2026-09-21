# frozen_string_literal: true

# Named to sort late among its neighbours on purpose: the integration suite's
# FactoryBot sequences run process-wide, so a spec that creates records shifts
# every recorded example that runs after it and the checked-in spec carries the
# drift. See spec/support/deterministic_openapi.rb.

require 'swagger_helper'

RSpec.describe 'Wishlist Items API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:wishlist) { create(:wishlist, customer: user, store: store, name: 'My Wishlist') }
  let!(:product) { create(:product) }
  let!(:wishlist_item) { create(:wishlist_item, wishlist: wishlist, variant: product.default_variant) }
  let(:wishlist_id) { wishlist.prefixed_id }

  path '/api/v3/store/wishlists/{wishlist_id}/items' do
    get 'List the goods on a wishlist' do
      tags 'Wishlists'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        What the customer has collected, most recently collected first. `category_id` narrows it to
        one category: the ids come from the categories read beside it, and a category this store
        does not have answers 404 rather than an empty page.
      DESC

      sdk_example 'wishlists/items-list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :wishlist_id, in: :path, type: :string, required: true,
                description: 'Wishlist prefixed ID (e.g., wl_abc123)'
      parameter name: :category_id, in: :query, type: :string, required: false,
                description: 'Category prefixed ID, from the categories read beside this one'
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :limit, in: :query, type: :integer, required: false
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort order. Prefix with - for descending. Values: created_at, -created_at'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (variant, product)'

      response '200', 'collected goods listed' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/WishlistItem' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               },
               required: %w[data meta]

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].map { |item| item['id'] }).to eq([wishlist_item.prefixed_id])
        end
      end

      response '404', 'the wishlist is not this customer’s' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:wishlist_id) { create(:wishlist, customer: create(:user), store: store).prefixed_id }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/wishlists/{wishlist_id}/items/categories' do
    get 'List the categories a wishlist’s goods fall into' do
      tags 'Wishlists'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        The tabs above a wishlist page: one entry per category any collected good is in, in the
        order the catalogue presents categories in. Categories with nothing collected in them are
        not listed, and neither are a sibling store's.
      DESC

      sdk_example 'wishlists/items-categories'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :wishlist_id, in: :path, type: :string, required: true,
                description: 'Wishlist prefixed ID (e.g., wl_abc123)'

      response '200', 'categories listed' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:category) { create(:category, store: store, name: 'Tea') }

        before { product.categories << category }

        schema type: :object,
               properties: { data: { type: :array, items: { '$ref' => '#/components/schemas/Category' } } },
               required: %w[data]

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].map { |entry| entry['id'] }).to eq([category.prefixed_id])
        end
      end
    end
  end
end
