require 'spec_helper'

RSpec.describe 'the membership operator reads', type: :request do
  include_context 'API v3 Admin'

  let(:headers) { bearer_headers }

  let(:group) { create(:customer_group, store: store) }


  # The banner a tier's members see: a group has at most one, so it is written
  # and read the way the group's settings row is.
  describe 'the tier banner' do
    it 'writes it and answers what it wrote' do
      post "/api/v3/admin/customer_groups/#{group.prefixed_id}/banner", headers: headers,
           params: { name: '会员中心', pic: 'https://cdn.example.com/banner.png',
                     areas: [{ area_rem: 'left: 1rem;top: 2rem;', link: '/pages/member/index' }] }

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include('name' => '会员中心', 'pic' => 'https://cdn.example.com/banner.png')
      expect(response.parsed_body['areas'].first).to include(
        'area_rem' => 'left: 1rem;top: 2rem;', 'link' => '/pages/member/index'
      )
    end

    # Permitted parameters drop an `areas` they cannot permit, so a payload that
    # named targets and sent something else would be saved as a banner with
    # none: refused rather than answered 201.
    it 'refuses targets that are not a list' do
      post "/api/v3/admin/customer_groups/#{group.prefixed_id}/banner", headers: headers,
           params: { pic: 'https://cdn.example.com/banner.png', areas: 'oops' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(Spree::MembershipBanner.count).to eq(0)

      post "/api/v3/admin/customer_groups/#{group.prefixed_id}/banner", headers: headers,
           params: { pic: 'https://cdn.example.com/banner.png', areas: %w[a b] }

      expect(response).to have_http_status(:unprocessable_content)
      expect(Spree::MembershipBanner.count).to eq(0)
    end

    # A group of another store is not this store's to write, and its own banner
    # is not touched.
    it 'answers 404 for a group of another store' do
      elsewhere = create(:customer_group, store: create(:store))

      post "/api/v3/admin/customer_groups/#{elsewhere.prefixed_id}/banner", headers: headers,
           params: { pic: 'https://cdn.example.com/banner.png' }

      expect(response).to have_http_status(:not_found)
      expect(Spree::MembershipBanner.count).to eq(0)
    end

    it 'answers 404 while a tier has no banner' do
      get "/api/v3/admin/customer_groups/#{group.prefixed_id}/banner", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    # An operator changes the picture or a target without touching the rest.
    it 'updates the one it already has' do
      create(:membership_banner, customer_group: group)

      patch "/api/v3/admin/customer_groups/#{group.prefixed_id}/banner", headers: headers,
            params: { name: '新名字' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['name']).to eq('新名字')
    end
  end

  describe 'GET /api/v3/admin/membership_rights/types' do
    it 'answers the registry, each kind with the settings it declares' do
      get '/api/v3/admin/membership_rights/types', headers: headers

      expect(response).to have_http_status(:ok)
      types = response.parsed_body['data']
      expect(types.map { |type| type['type'] }).to include('birthday_double_integral', 'member_price')

      birthday = types.find { |type| type['type'] == 'birthday_double_integral' }
      expect(birthday['preference_schema'].map { |field| field['key'] }).to include('multiplier')
    end
  end

  describe 'the rights a tier carries' do
    it 'creates one of a kind, with the settings that kind declares' do
      post "/api/v3/admin/customer_groups/#{group.prefixed_id}/membership_rights", headers: headers,
           params: { type: 'birthday_double_integral', name: '生日双倍', published: true,
                     preferences: { multiplier: 3 } }

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include('type' => 'birthday_double_integral', 'name' => '生日双倍')
      right = Spree::MembershipRight.last
      expect(right.preferred_multiplier).to eq(3)
    end

    it 'refuses a kind nothing registered' do
      post "/api/v3/admin/customer_groups/#{group.prefixed_id}/membership_rights", headers: headers,
           params: { type: 'free_shipping' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']['code']).to eq('unknown_membership_right_type')
    end

    it 'lists and updates what the tier carries' do
      right = create(:membership_right, customer_group: group)

      get "/api/v3/admin/customer_groups/#{group.prefixed_id}/membership_rights", headers: headers
      expect(response.parsed_body['data'].map { |row| row['id'] }).to eq([right.prefixed_id])

      patch "/api/v3/admin/customer_groups/#{group.prefixed_id}/membership_rights/#{right.prefixed_id}",
            headers: headers, params: { name: '改过的名字' }
      expect(response).to have_http_status(:ok)
      expect(right.reload.name).to eq('改过的名字')
    end
  end

  describe 'what makes a group a tier' do
    it 'answers 404 while the group is not one' do
      get "/api/v3/admin/customer_groups/#{group.prefixed_id}/tier_setting", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'creates and updates it once the group is a tier' do
      post "/api/v3/admin/customer_groups/#{group.prefixed_id}/tier_setting", headers: headers,
           params: { rank: 2, threshold: 500, validity_days: 365 }

            expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include('rank' => 2, 'threshold' => '500.0', 'validity_days' => 365)

      patch "/api/v3/admin/customer_groups/#{group.prefixed_id}/tier_setting", headers: headers,
            params: { threshold: 800 }
      expect(response).to have_http_status(:ok)
      expect(Spree::MembershipTierSetting.find_by(customer_group: group).threshold).to eq(800)
    end

    it 'refuses a second one for the same group' do
      create(:membership_tier_setting, customer_group: group)

      post "/api/v3/admin/customer_groups/#{group.prefixed_id}/tier_setting", headers: headers,
           params: { rank: 3 }

      expect(response).to have_http_status(:unprocessable_content)
    end

    # The member price is set here and read back here: the operator never has to
    # visit the catalogues page to say what a tier gives its members.
    it 'takes a member price with the tier, and answers it back' do
      post "/api/v3/admin/customer_groups/#{group.prefixed_id}/tier_setting", headers: headers,
           params: { rank: 2, member_discount_percentage: 10 }

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include('member_discount_percentage' => '10.0')

      patch "/api/v3/admin/customer_groups/#{group.prefixed_id}/tier_setting", headers: headers,
            params: { member_discount_percentage: 15 }
      expect(response).to have_http_status(:ok)

      setting = Spree::MembershipTierSetting.find_by(customer_group: group)
      expect(setting.reload.member_discount_percentage).to eq(15)
      expect(setting.catalog.price_list.price_adjustment_percentage).to eq(-15)
    end
  end
  describe 'the cards and the terms' do
    let(:customer) { create(:customer) }
    let!(:card) { create(:membership_card, customer: customer, customer_group: group) }

    it 'lists the cards, each with whose it is' do
      get '/api/v3/admin/membership_cards', headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data'].first).
        to include('status' => 'dormant', 'customer_id' => customer.prefixed_id)
    end

    it 'lists the terms' do
      create(:membership, customer: customer, customer_group: group)

      get '/api/v3/admin/memberships', headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data'].first).to include('status' => 'active', 'customer_id' => customer.prefixed_id)
    end

    # The one write this surface has: a card the client cannot void.
    it 'voids a card' do
      post "/api/v3/admin/membership_cards/#{card.prefixed_id}/recycling", headers: headers,
           params: { reason: 'reported lost' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('status' => 'recycled')
      expect(card.reload).to be_recycled
    end

    it 'answers 404 for a card of another store' do
      other_store = create(:store)
      other = create(:membership_card, store: other_store, customer: create(:customer),
                                       customer_group: create(:customer_group, store: other_store))

      post "/api/v3/admin/membership_cards/#{other.prefixed_id}/recycling", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
