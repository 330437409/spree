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
end
