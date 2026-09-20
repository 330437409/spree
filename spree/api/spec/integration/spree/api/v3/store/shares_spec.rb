# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Shares API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:product) { create(:product, store: store, name: '青花瓷茶具') }
  let(:other_store_product) { create(:product, store: create(:store)) }

  # What the client's decoder makes of the link: it splits `typeId` on `_` and
  # turns each `-` into `=`, and the page reads the query through a URL parser
  # (static/behaviors/locationLinkBehavior.js:7-13).
  def decoded_query(path)
    type_id = path[/typeId=([^&]+)/, 1]
    return '' if type_id.nil?

    CGI.unescape(type_id.split('_').map { |part| part.split('-').join('=') }.join('&'))
  end

  path '/api/v3/store/shares' do
    post 'Compose a share card' do
      tags 'Shares'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        What a WeChat share card says, and where it opens, for the thing the request names:
        a title, a subtitle, an image and the path the client assigns to its share API.

        One payload for every kind of thing a storefront shares — a product today, an
        invitation, a coupon or a team as those plans land — so the link's grammar has one
        implementation rather than one per domain. The QR and the poster belong to the
        mini-program identity capability and are absent until a target can ask it for them.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'x-spree-channel', in: :header, type: :string, required: false,
                description: 'Channel code or prefixed ID the shared thing is resolved in'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          target_type: { type: :string, example: 'product',
                         description: 'What kind of thing is being shared, in the api_type shorthand the rest of v3 uses' },
          target_id: { type: :string, example: 'prod_abc123',
                       description: 'Prefixed ID of the thing being shared' },
          context: { type: :object, additionalProperties: true,
                     description: 'What the target itself needs — a binding to mint, a team to join' }
        },
        required: %w[target_type target_id]
      }

      response '200', 'the card for a product' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { target_type: 'product', target_id: product.prefixed_id } }

        schema Spree::Api::OpenAPI::SchemaHelper.ref('StoreShare')

        run_test! do |response|
          data = JSON.parse(response.body)

          expect(data['title']).to eq('青花瓷茶具')
          expect(data['image_url']).to be_nil
          expect(data['path']).to start_with('/pages/index?type=inviteGoods&typeId=')
          # The link opens the product, from the shop that shared it.
          expect(decoded_query(data['path'])).to eq("id=#{product.prefixed_id}&originalSiteId=#{store.prefixed_id}")
          # The QR and the poster are the identity capability's.
          expect(data['qrcode_url']).to be_nil
          expect(data['poster_url']).to be_nil
        end
      end

      response '422', 'a request that names nothing to share' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { target_type: 'product' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          expect(JSON.parse(response.body)['error']['message']).to include('required')
        end
      end

      response '404', 'a kind of thing this storefront does not share' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { target_type: 'spaceship', target_id: product.prefixed_id } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      # A product another store sells is not this storefront's to share.
      response '404', 'a product belonging to another store' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { target_type: 'product', target_id: other_store_product.prefixed_id } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      # Nor is one this storefront does not show: a share is a link to a page
      # that would have nothing to render.
      response '404', 'a product this storefront does not show' do
        let(:draft_product) { create(:product, store: store, status: 'draft') }
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { target_type: 'product', target_id: draft_product.prefixed_id } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          # The target resolves, but nothing prices or shows it — so it is
          # absent from the relation the type declares.
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
