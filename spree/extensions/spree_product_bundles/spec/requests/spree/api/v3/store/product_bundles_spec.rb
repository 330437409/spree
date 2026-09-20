require 'spec_helper'

RSpec.describe 'the storefront bundle reads', type: :request do
  include_context 'API v3 Store authenticated'

  let(:headers) { bearer_headers }
  let(:tea) { create(:product, store: store, seller: nil, price: 60).default_variant }
  let(:cup) { create(:product, store: store, seller: nil, price: 40).default_variant }
  let(:category) { create(:category, store: store) }

  let!(:bundle) do
    create(:product_bundle, store: store, title: '双人下午茶套餐', components: { tea => 1, cup => 2 })
      .tap { |record| record.update!(status: 'active') }
  end

  describe 'the list' do
    it 'answers the bundles a storefront shows' do
      get '/api/v3/store/product_bundles', headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data'].pluck('id')).to eq([bundle.prefixed_id])
    end

    it 'leaves a bundle the merchant has not activated out' do
      bundle.update!(status: 'draft')

      get '/api/v3/store/product_bundles', headers: headers

      expect(response.parsed_body['data']).to eq([])
    end

    # The client's first call: the combos a goods belongs to.
    it 'filters by the goods a bundle is made of' do
      other = create(:product, store: store, seller: nil).default_variant
      create(:product_bundle, store: store, components: { other => 1 }).tap { |record| record.update!(status: 'active') }

      get '/api/v3/store/product_bundles', headers: headers, params: { q: { with_component_variant: tea.prefixed_id } }

      expect(response.parsed_body['data'].pluck('id')).to eq([bundle.prefixed_id])
    end

    # The client's third call: the menu's combo zone, by category.
    it 'filters by a category its components are in' do
      tea.product.categories << category

      get '/api/v3/store/product_bundles', headers: headers, params: { q: { in_category: category.prefixed_id } }

      expect(response.parsed_body['data'].pluck('id')).to eq([bundle.prefixed_id])
    end
  end

  describe 'one bundle' do
    it 'answers the components, what the set costs and what it saves' do
      get "/api/v3/store/product_bundles/#{bundle.prefixed_id}", headers: headers

      body = response.parsed_body
      expect(response).to have_http_status(:ok)
      expect(body['title']).to eq('双人下午茶套餐')
      expect(body['goods_price']).to eq(140.0)
      expect(body['saving']).to eq(0.0)
      expect(body['price']).to eq(140.0)

      tea_row = body['components'].find { |component| component['variant_id'] == tea.prefixed_id }
      expect(tea_row['quantity']).to eq(1)
      expect(tea_row['price']).to eq(60.0)
      expect(tea_row['goods_amount']).to eq(60.0)
      expect(tea_row['product_id']).to eq(tea.product.prefixed_id)
    end

    it 'answers what the set saves when the merchant gave it a rule' do
      bundle.preferred_discount_value = 20
      bundle.preferred_discount_kind = 'amount'
      bundle.save!

      get "/api/v3/store/product_bundles/#{bundle.prefixed_id}", headers: headers

      expect(response.parsed_body['price']).to eq(120.0)
      expect(response.parsed_body['saving']).to eq(20.0)
    end

    # The number the client compares a combo quantity against, in bundles.
    it 'answers how many sets the shelf can fill' do
      create(:stock_level, variant: tea, stock_location: Spree::StockLocation.first,
                           count_on_hand: 5, backorderable: false, adjust_count_on_hand: false)
      create(:stock_level, variant: cup, stock_location: Spree::StockLocation.first,
                           count_on_hand: 9, backorderable: false, adjust_count_on_hand: false)

      get "/api/v3/store/product_bundles/#{bundle.prefixed_id}", headers: headers

      expect(response.parsed_body['available']).to eq(4)
    end

    it 'answers a bundle by its slug too' do
      get "/api/v3/store/product_bundles/#{CGI.escape(bundle.slug)}", headers: headers

      expect(response.parsed_body['id']).to eq(bundle.prefixed_id)
    end

    it 'refuses a bundle this storefront does not show' do
      bundle.update!(status: 'archived')

      get "/api/v3/store/product_bundles/#{bundle.prefixed_id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
