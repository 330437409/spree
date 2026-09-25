require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::WishlistItemsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:wishlist) { create(:wishlist, customer: user, store: store) }
  let(:product) { create(:product) }
  let(:variant) { create(:variant, product: product) }
  let!(:wishlist_item) { create(:wishlist_item, wishlist: wishlist, variant: variant) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'GET #index' do
    it 'lists what was collected last first' do
      older = create(:wishlist_item, wishlist: wishlist, variant: create(:variant), created_at: 2.days.ago)

      get :index, params: { wishlist_id: wishlist.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |item| item['id'] }).to eq([wishlist_item.prefixed_id, older.prefixed_id])
    end

    it 'narrows to a category when the tab asks for one' do
      category = create(:category, store: store)
      product.categories << category
      other_item = create(:wishlist_item, wishlist: wishlist, variant: create(:variant))

      get :index, params: { wishlist_id: wishlist.prefixed_id, category_id: category.prefixed_id }

      ids = json_response['data'].map { |item| item['id'] }
      expect(ids).to eq([wishlist_item.prefixed_id])
      expect(ids).not_to include(other_item.prefixed_id)
    end

    # A tab naming a category this store does not have — a sibling store's, or
    # one deleted since the page was rendered — is not a filter that selects
    # nothing, it is a tab that has no business existing.
    it 'answers 404 for a category of another store' do
      other_store_category = create(:category, store: create(:store))

      get :index, params: { wishlist_id: wishlist.prefixed_id, category_id: other_store_category.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end

    it 'answers 404 for another customer’s wishlist' do
      other_wishlist = create(:wishlist, customer: create(:user), store: store)

      get :index, params: { wishlist_id: other_wishlist.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET #categories' do
    it 'answers the categories the collected goods fall into, and no others' do
      category = create(:category, store: store)
      product.categories << category
      create(:wishlist_item, wishlist: wishlist, variant: create(:variant))
      create(:category, store: store, name: 'Nothing collected from here')

      get :categories, params: { wishlist_id: wishlist.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |entry| entry['id'] }).to eq([category.prefixed_id])
      expect(json_response['data'].first['name']).to eq(category.name)
    end

    it 'does not answer a sibling store’s category' do
      other_store = create(:store)
      other_category = create(:category, store: other_store)
      other_product = create(:product, store: other_store)
      other_product.categories << other_category
      create(:wishlist_item, wishlist: wishlist, variant: other_product.default_variant)

      get :categories, params: { wishlist_id: wishlist.prefixed_id }

      expect(json_response['data']).to be_empty
    end
  end

  describe 'POST #create' do
    let(:new_product) { create(:product) }
    let(:new_variant) { create(:variant, product: new_product) }

    it 'adds item to wishlist' do
      expect {
        post :create, params: { wishlist_id: wishlist.prefixed_id, variant_id: new_variant.prefixed_id, quantity: 3 }
      }.to change(Spree::WishlistItem, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['variant_id']).to eq(new_variant.prefixed_id)
      expect(json_response['product_id']).to eq(new_product.prefixed_id)
      expect(json_response['quantity']).to eq(3)
    end

    context 'validation errors' do
      it 'returns errors for missing variant_id' do
        post :create, params: { wishlist_id: wishlist.prefixed_id, quantity: 1 }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('validation_error')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns not found for an unknown variant_id' do
        post :create, params: { wishlist_id: wishlist.prefixed_id, variant_id: 0, quantity: 1 }

        expect(response).to have_http_status(:not_found)
      end
    end

    # The item renders its variant and product, so a variant the listing
    # would not show must read as missing.
    context 'with a variant the buyer cannot see' do
      it 'refuses a draft product' do
        draft_variant = create(:variant, product: create(:product, status: 'draft'))

        expect {
          post :create, params: { wishlist_id: wishlist.prefixed_id, variant_id: draft_variant.prefixed_id }
        }.not_to change(Spree::WishlistItem, :count)

        expect(response).to have_http_status(:not_found)
      end

      it 'refuses a raw integer id' do
        post :create, params: { wishlist_id: wishlist.prefixed_id, variant_id: new_variant.id }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'error handling' do
      it 'returns not found for other users wishlist' do
        other_user = create(:user)
        other_wishlist = create(:wishlist, customer: other_user, store: store)

        post :create, params: { wishlist_id: other_wishlist.prefixed_id, variant_id: new_variant.prefixed_id, quantity: 1 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns not found for non-existent wishlist' do
        post :create, params: { wishlist_id: 0, variant_id: new_variant.prefixed_id, quantity: 1 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        post :create, params: { wishlist_id: wishlist.prefixed_id, variant_id: new_variant.prefixed_id, quantity: 1 }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
        expect(json_response['error']['message']).to be_present
      end
    end
  end

  describe 'PATCH #update' do
    it 'updates wishlist item quantity' do
      patch :update, params: { wishlist_id: wishlist.prefixed_id, id: wishlist_item.prefixed_id, quantity: 5 }

      expect(response).to have_http_status(:ok)
      expect(wishlist_item.reload.quantity).to eq(5)
    end

    context 'validation errors' do
      it 'returns errors for invalid quantity' do
        patch :update, params: { wishlist_id: wishlist.prefixed_id, id: wishlist_item.prefixed_id, quantity: 0 }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('validation_error')
        expect(json_response['error']['details']['quantity']).to be_present
      end
    end

    context 'error handling' do
      it 'returns not found for non-existent item' do
        patch :update, params: { wishlist_id: wishlist.prefixed_id, id: 0, quantity: 5 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns not found for item in other users wishlist' do
        other_user = create(:user)
        other_wishlist = create(:wishlist, customer: other_user, store: store)
        other_item = create(:wishlist_item, wishlist: other_wishlist, variant: variant)

        patch :update, params: { wishlist_id: other_wishlist.prefixed_id, id: other_item.prefixed_id, quantity: 5 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'removes item from wishlist' do
      expect {
        delete :destroy, params: { wishlist_id: wishlist.prefixed_id, id: wishlist_item.prefixed_id }
      }.to change(Spree::WishlistItem, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    context 'error handling' do
      it 'returns not found for non-existent item' do
        delete :destroy, params: { wishlist_id: wishlist.prefixed_id, id: 0 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns not found for item in other users wishlist' do
        other_user = create(:user)
        other_wishlist = create(:wishlist, customer: other_user, store: store)
        other_item = create(:wishlist_item, wishlist: other_wishlist, variant: variant)

        delete :destroy, params: { wishlist_id: other_wishlist.prefixed_id, id: other_item.prefixed_id }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end
    end
  end
end
