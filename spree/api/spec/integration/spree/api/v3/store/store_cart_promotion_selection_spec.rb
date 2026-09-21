# frozen_string_literal: true

# Named to sort late among its neighbours on purpose: the integration suite's
# FactoryBot sequences run process-wide, so a spec that creates records shifts
# every recorded example that runs after it and the checked-in spec carries the
# drift. See spec/support/deterministic_openapi.rb.

require 'swagger_helper'

RSpec.describe 'Cart Promotion Selection API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:cart) { create(:cart, store: store, customer: user) }
  let!(:product) { create(:product) }
  let(:cart_id) { cart.prefixed_id }
  let(:line_item) { cart.line_items.reload.first }
  let(:weak) { create(:promotion_with_item_adjustment, adjustment_rate: 5, kind: :automatic, store: store) }
  let(:strong) { create(:promotion_with_item_adjustment, adjustment_rate: 30, kind: :automatic, store: store) }

  before do
    Spree::Carts::AddItem.call(cart: cart, variant: product.default_variant, quantity: 2)
    weak.activate(order: cart)
    strong.activate(order: cart)
    cart.recalculate_totals!
  end

  path '/api/v3/store/carts/{cart_id}/promotion_selection' do
    post 'Choose which promotion discounts a line' do
      tags 'Carts'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        The shopper's answer when more than one promotion could discount a line. The engine
        computes the candidates and applies one winner; this names another of them, and every
        recalculation after it gives that line the promotion the shopper chose.

        Both identities come from the server's own list — the cart's line carries
        `promotion_candidates` — so a promotion that does not apply to the line, or a code that
        no longer matches the candidate's, is refused rather than guessed at. A promotion that
        applies to several lines needs `line_item_id` to say which one is meant.
      DESC

      sdk_example 'carts/promotion-selection-create'

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
          promotion_id: { type: :string, example: 'promo_abc123',
                          description: 'One of the line’s promotion_candidates' },
          promotion_code: { type: :string, example: 'SAVE5',
                            description: 'The candidate’s own code, when it has one' },
          line_item_id: { type: :string, example: 'li_abc123',
                          description: 'Which line, when the promotion applies to more than one' }
        },
        required: %w[promotion_id]
      }

      response '200', 'the cart, priced with the chosen promotion' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'x-spree-token') { cart.token }
        let(:body) { { promotion_id: weak.prefixed_id, line_item_id: line_item.prefixed_id } }

        schema '$ref' => '#/components/schemas/Cart'

        run_test! do |response|
          data = JSON.parse(response.body)
          chosen = data['items'].find { |item| item['id'] == line_item.prefixed_id }
          expect(chosen['promotion_id']).to eq(weak.prefixed_id)
        end
      end

      response '422', 'a promotion this line could not be discounted by' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'x-spree-token') { cart.token }
        let(:body) { { promotion_id: create(:promotion, store: store).prefixed_id, line_item_id: line_item.prefixed_id } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          expect(JSON.parse(response.body)['error']['message']).to include('does not apply')
        end
      end
    end
  end
end
