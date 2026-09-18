require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::ProductsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:product) { create(:product, status: 'active') }
  let!(:seller) { create(:seller, :approved, store: store, slug: 'nanshan') }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'Spree::Api::V3::Store::SellerResolution' do
    # Read from the controller — Spree::Current resets between requests.
    def resolved_seller
      controller.send(:current_seller)
    end

    it 'resolves the seller from X-Spree-Seller-Id by prefixed ID' do
      request.headers['x-spree-seller-id'] = seller.prefixed_id
      get :index

      expect(response).to have_http_status(:ok)
      expect(resolved_seller).to eq(seller)
    end

    it 'resolves the seller by slug' do
      request.headers['x-spree-seller-id'] = 'nanshan'
      get :index

      expect(response).to have_http_status(:ok)
      expect(resolved_seller).to eq(seller)
    end

    it 'writes the seller into Spree::Current for the rest of the request' do
      request.headers['x-spree-seller-id'] = seller.prefixed_id
      controller.singleton_class.define_method(:index) do
        render plain: Spree::Current.seller&.prefixed_id.to_s
      end

      get :index

      expect(response.body).to eq(seller.prefixed_id)
    end

    it 'leaves the seller unset when the header is absent' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(resolved_seller).to be_nil
    end

    it 'refuses a prefixed ID this store does not have' do
      request.headers['x-spree-seller-id'] = 'sel_nonexistent'
      get :index

      expect(response).to have_http_status(:not_found)
      expect(json_response[:error][:code]).to eq('seller_not_found')
    end

    it 'refuses a slug this store does not have' do
      request.headers['x-spree-seller-id'] = 'no-such-site'
      get :index

      expect(response).to have_http_status(:not_found)
      expect(json_response[:error][:code]).to eq('seller_not_found')
    end

    it 'scopes the lookup to the current store' do
      other_seller = create(:seller, :approved, store: create(:store, code: 'other-store'))

      request.headers['x-spree-seller-id'] = other_seller.prefixed_id
      get :index

      expect(response).to have_http_status(:not_found)
      expect(json_response[:error][:code]).to eq('seller_not_found')
    end
  end
end
