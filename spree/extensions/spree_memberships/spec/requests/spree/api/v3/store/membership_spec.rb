require 'spec_helper'

RSpec.describe 'the membership reads', type: :request do
  include_context 'API v3 Store authenticated'

  let(:group) { create(:customer_group, store: store) }
  let!(:tier) { create(:membership_tier_setting, customer_group: group, rank: 1) }
  let!(:right) { create(:membership_right, customer_group: group) }

  describe 'GET /api/v3/store/membership_rights' do
    it 'answers the rights catalogue, each with the tier it belongs to' do
      get '/api/v3/store/membership_rights', headers: headers

      expect(response).to have_http_status(:ok)
      row = response.parsed_body['data'].first
      expect(row).to include('type' => 'exclusive_coupon', 'name' => 'Exclusive coupon', 'published' => true)
      expect(row['tier']).to include('rank' => 1)
    end

    it 'answers nothing for a tier of another store' do
      elsewhere = create(:customer_group, store: create(:store))
      create(:membership_tier_setting, customer_group: elsewhere)
      create(:membership_right, customer_group: elsewhere)

      get '/api/v3/store/membership_rights', headers: headers

      expect(response.parsed_body['data'].map { |row| row['id'] }).to eq([right.prefixed_id])
    end
  end

  describe 'GET /api/v3/store/membership_tiers' do
    it 'answers the ladder in rank order' do
      other_group = create(:customer_group, store: store)
      create(:membership_tier_setting, customer_group: other_group, rank: 0)

      get '/api/v3/store/membership_tiers', headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data'].map { |row| row['rank'] }).to eq([0, 1])
    end

    it 'requires a signed-in customer' do
      get '/api/v3/store/membership_tiers', headers: api_key_headers

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v3/store/customers/me/membership' do
    it 'answers a null tier for a customer who is in none' do
      get '/api/v3/store/customers/me/membership', headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['tier']).to be_nil
      expect(response.parsed_body['rights_total']).to eq(0)

      # A panel is the ladder rather than "my tier's rights", so a customer in
      # no tier still sees what there is to be had — marked as not theirs.
      expect(response.parsed_body['sections']['vipCouponInfoVo'].first).to include('is_have' => false)
    end

    it 'answers the tier, its sections and how many rights it carries' do
      group.add_customers([user.id])

      get '/api/v3/store/customers/me/membership', headers: headers

      expect(response.parsed_body['tier']).to include('rank' => 1)
      expect(response.parsed_body['rights_total']).to eq(1)
      expect(response.parsed_body['sections']['vipCouponInfoVo'].first).
        to include('type' => 'exclusive_coupon', 'is_have' => true)
    end
  end
  describe 'the card wallet' do
    let(:card) { create(:membership_card, customer: user, customer_group: group) }

    it 'answers the customer’s own cards, with what each one is waiting for' do
      card

      get '/api/v3/store/customers/me/membership_cards', headers: headers

      expect(response).to have_http_status(:ok)
      row = response.parsed_body['data'].first
      expect(row).to include('status' => 'dormant', 'giftable' => true)
      expect(row['tier']).to include('rank' => 1)
    end

    it 'activates a card and answers the term it started' do
      post "/api/v3/store/customers/me/membership_cards/#{card.prefixed_id}/activations", headers: headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include('status' => 'active')
      expect(response.parsed_body['membership']).to include('status' => 'active')
      expect(user.reload.customer_groups).to include(group)
    end

    # Read through the customer's own cards, so somebody else's is not found.
    it 'answers 404 for a card that is not theirs' do
      other = create(:membership_card, customer: create(:customer), customer_group: group)

      post "/api/v3/store/customers/me/membership_cards/#{other.prefixed_id}/activations", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'refuses a card whose deadline to activate passed' do
      card.update!(activates_before: 1.day.ago)

      post "/api/v3/store/customers/me/membership_cards/#{card.prefixed_id}/activations", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
  describe 'giving a card away' do
    let(:card) { create(:membership_card, customer: user, customer_group: group) }

    it 'opens a window and answers the token the client shares' do
      post "/api/v3/store/customers/me/membership_cards/#{card.prefixed_id}/transfers", headers: headers,
           params: { to_phone: '13800000000', message: '生日快乐', expires_at: 7.days.from_now.iso8601 }

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include('status' => 'pending', 'message' => '生日快乐')
      expect(response.parsed_body['token']).to be_present
      expect(card.reload).to be_dormant
    end

    it 'shows the window on the wallet, which is what 赠送中 reads' do
      create(:transfer, from_customer: user, transferable: card, to_phone: '13800000000')

      get '/api/v3/store/customers/me/membership_cards', headers: headers

      expect(response.parsed_body['data'].first['transfer']).to include('status' => 'pending')
    end

    it 'refuses a card the customer may not give away' do
      card.update!(giftable: false)

      post "/api/v3/store/customers/me/membership_cards/#{card.prefixed_id}/transfers", headers: headers,
           params: { to_phone: '13800000000', expires_at: 7.days.from_now.iso8601 }

      expect(response).to have_http_status(:unprocessable_content)
      expect(Spree::Transfer.count).to eq(0)
    end

    it 'takes the window back when the giver cancels it' do
      window = create(:transfer, from_customer: user, transferable: card, to_phone: '13800000000')

      delete "/api/v3/store/customers/me/membership_cards/#{card.prefixed_id}/transfers/#{window.prefixed_id}",
             headers: headers

      expect(response).to have_http_status(:ok)
      expect(window.reload).to be_canceled
    end
  end

  describe 'receiving one' do
    let(:card) { create(:membership_card, customer: create(:customer), customer_group: group) }
    let(:window) { create(:transfer, from_customer: card.customer, transferable: card, to_phone: '13800000000') }

    # The recipient reads it before signing in: the token is the address, and
    # nobody's identity comes with it.
    it 'answers the card a token points at, without a signed-in customer' do
      get "/api/v3/store/membership_card_transfers/#{window.token}", headers: api_key_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('status' => 'pending')
      expect(response.parsed_body['card']).to include('status' => 'dormant')
      expect(response.parsed_body.to_s).not_to include(card.customer.prefixed_id)
    end

    it 'claims it, activating the card for whoever claimed it' do
      post "/api/v3/store/membership_card_transfers/#{window.token}/claims", headers: headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include('status' => 'accepted')
      expect(card.reload).to be_active
      expect(card.membership.customer).to eq(user)
      expect(user.reload.customer_groups).to include(group)
    end

    it 'answers 404 for a token nobody holds' do
      get '/api/v3/store/membership_card_transfers/nothing-here', headers: api_key_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'refuses a window that has closed, and says so rather than 404' do
      window.update_columns(expires_at: 1.hour.ago)

      get "/api/v3/store/membership_card_transfers/#{window.token}", headers: api_key_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('status' => 'expired')

      post "/api/v3/store/membership_card_transfers/#{window.token}/claims", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(card.reload).to be_dormant
    end
  end
end
