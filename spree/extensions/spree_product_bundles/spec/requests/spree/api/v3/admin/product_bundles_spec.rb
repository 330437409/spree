require 'spec_helper'

RSpec.describe 'the operator’s bundles', type: :request do
  include_context 'API v3 Admin'

  let(:headers) { bearer_headers }
  let(:tea) { create(:product, store: store, seller: nil, price: 60).default_variant }
  let(:cup) { create(:product, store: store, seller: nil, price: 40).default_variant }

  def create_bundle(title: '双人下午茶套餐', components: [{ variant_id: tea.prefixed_id, quantity: 1 }])
    post '/api/v3/admin/product_bundles', headers: headers, params: {
      title: title,
      status: 'active',
      preferred_discount_kind: 'amount',
      preferred_discount_value: 20,
      components: components
    }
  end

  describe 'creating one' do
    it 'writes the composition the payload names' do
      create_bundle(components: [
                      { variant_id: tea.prefixed_id, quantity: 1 },
                      { variant_id: cup.prefixed_id, quantity: 2 }
                    ])

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body['title']).to eq('双人下午茶套餐')
      expect(body['status']).to eq('active')
      expect(body['goods_price']).to eq(140.0)
      expect(body['price']).to eq(120.0)
      expect(body['saving']).to eq(20.0)
      expect(body['components'].map { |row| row['quantity'] }).to contain_exactly(1, 2)
      expect(Spree::ProductBundle.find_by_prefix_id(body['id']).variants).to contain_exactly(tea, cup)
    end

    # The composition is one seller's, and a cross-seller one is refused where
    # it is written rather than left to a marketplace's order split.
    it 'refuses a composition that crosses sellers' do
      first = create(:product, store: store, seller: create(:seller, store: store)).default_variant
      second = create(:product, store: store, seller: create(:seller, store: store)).default_variant

      create_bundle(components: [{ variant_id: first.prefixed_id, quantity: 1 },
                                 { variant_id: second.prefixed_id, quantity: 1 }])

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'refuses a title it cannot make a handle of' do
      create_bundle(title: '')

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'editing one' do
    let!(:bundle) do
      create(:product_bundle, store: store, components: { tea => 1, cup => 2 }).tap do |record|
        record.update!(status: 'active')
      end
    end

    # The payload is the whole set: a component left out is one the operator
    # removed.
    it 'replaces the composition with the one it is given' do
      patch "/api/v3/admin/product_bundles/#{bundle.prefixed_id}", headers: headers, params: {
        components: [{ variant_id: cup.prefixed_id, quantity: 3 }]
      }

      expect(response).to have_http_status(:ok)
      expect(bundle.reload.components.map(&:variant_id)).to eq([cup.id])
      expect(bundle.components.first.quantity).to eq(3)
    end

    it 'leaves the composition alone when the payload does not name one' do
      patch "/api/v3/admin/product_bundles/#{bundle.prefixed_id}", headers: headers, params: { title: '单人下午茶' }

      expect(response).to have_http_status(:ok)
      expect(bundle.reload.title).to eq('单人下午茶')
      expect(bundle.components.count).to eq(2)
    end

    it 'takes one off sale' do
      patch "/api/v3/admin/product_bundles/#{bundle.prefixed_id}", headers: headers, params: { status: 'archived' }

      expect(bundle.reload.status).to eq('archived')
    end
  end

  describe 'reading them' do
    let!(:bundle) { create(:product_bundle, store: store, title: '双人下午茶套餐', components: { tea => 1 }) }

    it 'lists what the store has' do
      get '/api/v3/admin/product_bundles', headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data'].pluck('id')).to eq([bundle.prefixed_id])
    end

    it 'answers one with its composition' do
      get "/api/v3/admin/product_bundles/#{bundle.prefixed_id}", headers: headers

      expect(response.parsed_body['components'].size).to eq(1)
    end

    it 'deletes one without touching the components themselves' do
      delete "/api/v3/admin/product_bundles/#{bundle.prefixed_id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(Spree::ProductBundle.count).to eq(0)
      expect(tea.reload).to be_present
    end
  end
end
