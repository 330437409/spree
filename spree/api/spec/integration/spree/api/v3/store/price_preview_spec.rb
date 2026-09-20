# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Price Preview API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:product) { create(:product, store: store, price: 100) }
  let(:variant) { product.default_variant }
  let(:other_store_variant) { create(:product, store: create(:store)).default_variant }

  path '/api/v3/store/price_preview' do
    post 'Preview the price of a basket' do
      tags 'Price Preview'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        Prices a set of variants and quantities, with no cart created — what the product page
        asks before anything exists, and what the settlement page asks with a cart later.

        Prices are resolved in the context the request carries: the channel it resolved, its
        currency, the country the buyer is taxed in, and the customer when there is one. It is
        the one price calculation the Store API offers, and the price it answers is the price
        the cart writes.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true,
                description: 'Publishable API key'
      parameter name: 'x-spree-channel', in: :header, type: :string, required: false,
                description: 'Channel code or prefixed ID the prices are resolved for'
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer JWT token (optional — for a signed-in customer)'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false,
                description: 'Guest cart token, when the request prices a cart the caller holds'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          currency: { type: :string, example: 'USD', description: 'Currency to price in; defaults to the request’s' },
          cart_id: { type: :string, example: 'cart_abc123',
                     description: 'Price the lines this cart holds instead of naming variants. Its own currency and its own context apply.' },
          context: { type: :object, additionalProperties: true,
                     description: 'What a registered source needs — a flash sale’s activity id, for instance.' },
          stock_location_id: { type: :string, example: 'sloc_abc123',
                               description: 'The warehouse the page is about, when it is about one: each line then answers that shop’s own shelf beside the goods’ total.' },
          items: {
            type: :array,
            description: 'The variants to price, with how many of each',
            items: {
              type: :object,
              properties: {
                variant_id: { type: :string, example: 'variant_abc123', description: 'Prefixed variant ID' },
                quantity: { type: :integer, example: 2, description: 'Quantity (defaults to 1)' }
              },
              required: %w[variant_id]
            }
          }
        },
        required: %w[items]
      }

      response '200', 'priced' do
        # The area context's own question: what this goods costs, and what the
        # shop the page is about has on its shelf.
        let(:warehouse) { create(:stock_location, store: store, name: '浦东仓') }
        # Ten the store ships from anywhere, three on this shop's own shelf —
        # the two figures the client switches between.
        let(:variant) do
          product.default_variant.tap do |record|
            create(:stock_level, variant: record, stock_location: store.default_stock_location,
                                 count_on_hand: 10, backorderable: false, adjust_count_on_hand: false)
            create(:stock_level, variant: record, stock_location: warehouse,
                                 count_on_hand: 3, backorderable: false, adjust_count_on_hand: false)
          end
        end
        let(:'x-spree-api-key') { api_key.token }
        let(:body) do
          { stock_location_id: warehouse.prefixed_id,
            items: [{ variant_id: variant.prefixed_id, quantity: 2 }] }
        end

        schema Spree::Api::OpenAPI::SchemaHelper.ref('StorePricePreview')

        run_test! do |response|
          data = JSON.parse(response.body)

          expect(data['items'].first['unit_amount']).to eq(100.0)
          expect(data['total']).to eq(200.0)
          expect(data['items'].first['variant_id']).to eq(variant.prefixed_id)
          # The goods' own availability, and the named shop's — both travel,
          # because the client switches between them on the basket it is building.
          expect(data['items'].first['available_quantity']).to eq(13)
          expect(data['items'].first['stock_location_quantity']).to eq(3)
          # Nothing time-boxes a catalogue price.
          expect(data['items'].first['price_ends_at']).to be_nil
        end
      end

      response '404', 'a variant this store does not have' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { items: [{ variant_id: 'variant_doesnotexist', quantity: 1 }] } }

        schema Spree::Api::OpenAPI::SchemaHelper.error_response

        run_test! do |response|
          expect(JSON.parse(response.body)['error']['code']).to be_present
        end
      end

      # A variant from another tenant is a 404 rather than a price — the same
      # rule every store-scoped lookup follows.
      response '404', 'a variant belonging to another store' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { items: [{ variant_id: other_store_variant.prefixed_id, quantity: 1 }] } }

        schema Spree::Api::OpenAPI::SchemaHelper.error_response

        run_test!
      end

      # Nor is a product the storefront does not show quotable by its variant id.
      response '404', 'a variant of a product the storefront does not show' do
        let(:draft_variant) { create(:product, status: 'draft', store: store).default_variant }
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { items: [{ variant_id: draft_variant.prefixed_id, quantity: 1 }] } }

        schema Spree::Api::OpenAPI::SchemaHelper.error_response

        run_test!
      end

      response '422', 'a payload that is not a list of items' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { items: {} } }

        schema Spree::Api::OpenAPI::SchemaHelper.error_response

        run_test!
      end

      response '422', 'a quantity that is not a positive whole number' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { items: [{ variant_id: variant.prefixed_id, quantity: -2 }] } }

        schema Spree::Api::OpenAPI::SchemaHelper.error_response

        run_test!
      end

      # The settle page's own shape: a cart rather than a list of variants.
      response '200', 'the lines a cart holds' do
        let(:cart) { create(:cart, store: store).tap { |record| create(:line_item, cart: record, variant: variant, quantity: 2, price: 100) } }
        let(:'x-spree-api-key') { api_key.token }
        # A guest reaches their own cart with its token, the same way the cart
        # endpoints do.
        let(:'x-spree-token') { cart.token }
        let(:body) { { cart_id: cart.prefixed_id } }

        schema Spree::Api::OpenAPI::SchemaHelper.ref('StorePricePreview')

        run_test! do |response|
          data = JSON.parse(response.body)

          expect(data['items'].length).to eq(1)
          expect(data['items'].first['variant_id']).to eq(variant.prefixed_id)
          expect(data['items'].first['quantity']).to eq(2)
          expect(data['total']).to eq(200.0)
        end
      end

      # A cart that is not this caller's — another customer's, or one whose
      # guest token does not match — is refused rather than priced.
      response '403', 'a cart that is not this caller’s' do
        let(:someone_elses_cart) { create(:cart, store: store) }
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { cart_id: someone_elses_cart.prefixed_id } }

        schema Spree::Api::OpenAPI::SchemaHelper.error_response

        run_test!
      end

      # A storefront that hides prices answers no amounts — the same posture the
      # product read applies — while the shelf's verdict still travels.
      #
      # Its own store rather than the default one: the posture is a setting on a
      # store row, and a spec that flips it on the shared row leaves every later
      # example in the shard reading hidden prices.
      response '200', 'no amounts on a storefront that hides prices' do
        let(:store) { create(:store, default: true, preferred_storefront_access: 'prices_hidden') }
        let(:product) { create(:product, store: store, price: 100) }
        let(:variant) { product.default_variant }
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { items: [{ variant_id: variant.prefixed_id, quantity: 1 }] } }

        schema Spree::Api::OpenAPI::SchemaHelper.ref('StorePricePreview')

        run_test! do |response|
          data = JSON.parse(response.body)

          expect(data['total']).to be_nil
          expect(data['items'].first['unit_amount']).to be_nil
          expect(data['items'].first).to have_key('in_stock')
        end
      end
    end
  end
end
