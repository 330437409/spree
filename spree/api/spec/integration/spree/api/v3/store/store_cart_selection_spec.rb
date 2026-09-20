# frozen_string_literal: true

# Named to sort late among its neighbours on purpose: the integration suite's
# FactoryBot sequences run process-wide, so a spec that creates records shifts
# every recorded example that runs after it and the checked-in spec carries the
# drift. See spec/support/deterministic_openapi.rb.

require 'swagger_helper'

RSpec.describe 'Cart Selection API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:order) { create(:cart, store: store, customer: user) }
  let!(:product) { create(:product) }
  let(:line_item) { order.line_items.reload.first }
  let(:cart_id) { order.prefixed_id }

  before do
    Spree::Carts::AddItem.call(cart: order, variant: product.default_variant, quantity: 2)
  end

  path '/api/v3/store/carts/{cart_id}/selection' do
    patch 'Choose which lines take part in checkout' do
      tags 'Carts'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Ticks or unticks lines of the cart in one write, over a set of line ids: one tick,
        or a whole group's. The ticks are durable cart state — the cart prices the ticked
        lines and completion copies them into the order — so no request in the checkout
        path names the selection again. The cart that comes back carries the new ticks
        beside the money of the lines that are left ticked.
      DESC

      sdk_example 'carts/selection-update'

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
          selected: { type: :boolean, example: false,
                      description: 'Whether the named lines take part in checkout' },
          line_item_ids: { type: :array, items: { type: :string }, example: %w[li_abc123],
                           description: 'Prefixed IDs of the lines to write. An id this cart does not hold is ignored' }
        },
        required: %w[selected line_item_ids]
      }

      response '200', 'the cart, priced over the lines that are left ticked' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { selected: false, line_item_ids: [line_item.prefixed_id] } }

        schema '$ref' => '#/components/schemas/Cart'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['items'].first['selected']).to be(false)
          expect(data['selected_quantity']).to eq(0)
          # Nothing is ticked, so nothing is priced.
          expect(data['item_total']).to eq('0.0')
        end
      end

      response '422', 'the write names no line' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { selected: true, line_item_ids: [] } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('validation_error')
          expect(line_item.reload.selected).to be(true)
        end
      end
    end
  end
end
