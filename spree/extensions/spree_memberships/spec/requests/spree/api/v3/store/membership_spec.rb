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
  # 立即领取 — the annual gift's claim, and the entry the panel reads the gift
  # off in the first place.
  describe 'POST /api/v3/store/customers/me/membership_rights/:id/year_gift_claims' do
    let(:coupon) { create(:promotion, store: store, name: 'A bottle of wine') }
    let(:other_coupon) { create(:promotion, store: store, name: 'Another bottle') }
    let!(:gift) do
      create(:give_gift_right, customer_group: group, published: true, preferences: {
        gift_promotion_ids: [coupon.prefixed_id, other_coupon.prefixed_id], yearly_limit: 1
      })
    end
    let(:path) { "/api/v3/store/customers/me/membership_rights/#{gift.prefixed_id}/year_gift_claims" }

    before { group.add_customers([user.id]) }

    it 'hands over the gift’s coupon' do
      post path, headers: headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include('source' => 'membership', 'status' => 'unused')
      expect(response.parsed_body['promotion']).to include('name' => 'A bottle of wine')
    end

    it 'lists the gift on the member centre entry, with what is left of it' do
      get '/api/v3/store/customers/me/membership', headers: headers

      entry = response.parsed_body['sections']['yearGiftLevelSettingVos'].first
      expect(entry['is_have']).to be(true)
      expect(entry['gift']).to include('mode' => 'coupon', 'can_count' => 1, 'usable_num' => 2)
      expect(entry['gift']['coupons'].first).
        to include('promotion_id' => coupon.prefixed_id, 'name' => 'A bottle of wine', 'claimed' => false)
    end

    # The allowance is spent while a coupon remains: the next claim is refused
    # rather than the gift being emptied.
    it 'refuses the claim past the year’s allowance' do
      post path, headers: headers
      post path, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']['message']).
        to eq(Spree.t('memberships.errors.gift_allowance_spent'))
    end

    it 'requires a signed-in customer' do
      post path, headers: api_key_headers

      expect(response).to have_http_status(:unauthorized)
    end

    # The ladder is where the store is, so a gift of another store's tier is not
    # one this customer may claim.
    it 'answers 404 for a right of another store' do
      other_store = create(:store)
      elsewhere = create(:give_gift_right, customer_group: create(:customer_group, store: other_store),
                                           preferences: {
                                             gift_promotion_ids: [create(:promotion, store: other_store).prefixed_id]
                                           })

      post "/api/v3/store/customers/me/membership_rights/#{elsewhere.prefixed_id}/year_gift_claims", headers: headers

      expect(response).to have_http_status(:not_found)
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

    # What the client opens its 恭喜升级 modal on: the tier's bag, read from the
    # rights the card's tier carries.
    it 'answers the bag entering the tier handed over' do
      create(:entry_integral_right, customer_group: group, published: true, preferences: { amount: 250 })

      post "/api/v3/store/customers/me/membership_cards/#{card.prefixed_id}/activations", headers: headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['entry_bag']).to eq('points' => 250, 'coupons' => 0)
    end

    # What the tier carries *now* is not what the member was given: an operator
    # raising the amount must not change what the wallet says was handed over.
    it 'does not re-report the bag on a later read' do
      right = create(:entry_integral_right, customer_group: group, published: true, preferences: { amount: 250 })
      post "/api/v3/store/customers/me/membership_cards/#{card.prefixed_id}/activations", headers: headers
      expect(response.parsed_body['entry_bag']).to eq('points' => 250, 'coupons' => 0)

      right.update!(preferences: { amount: 5000 })

      get '/api/v3/store/customers/me/membership_cards', headers: headers

      expect(response.parsed_body['data'].first['entry_bag']).to be_nil
    end

    # Read through the customer's own cards, so somebody else's is not found.
    it 'answers 404 for a card that is not theirs' do
      other = create(:membership_card, customer: create(:customer), customer_group: group)

      post "/api/v3/store/customers/me/membership_cards/#{other.prefixed_id}/activations", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    # 自己激活 while a window is open would strand it: the recipient's claim
    # would then be refused by a card that already has a term.
    # A window whose date has passed blocks nothing: the claim against it refuses
    # on its own, and the holder may activate their own card.
    it 'activates a card whose window has lapsed' do
      window = create(:transfer, from_customer: user, transferable: card, to_phone: '13800000000')
      window.update_columns(expires_at: 1.hour.ago)

      post "/api/v3/store/customers/me/membership_cards/#{card.prefixed_id}/activations", headers: headers

      expect(response).to have_http_status(:created)
      expect(card.reload).to be_active
    end

    it 'refuses to activate a card that is on its way to somebody' do
      create(:transfer, from_customer: user, transferable: card, to_phone: '13800000000')

      post "/api/v3/store/customers/me/membership_cards/#{card.prefixed_id}/activations", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(card.reload).to be_dormant
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

    it 'shows a window whose date has passed as expired' do
      window = create(:transfer, from_customer: user, transferable: card, to_phone: '13800000000')
      window.update_columns(expires_at: 1.hour.ago)

      get '/api/v3/store/customers/me/membership_cards', headers: headers

      expect(response.parsed_body['data'].first['transfer']).to include('status' => 'expired')
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

    # The gift nobody opened: the card is 待激活 again in the client, and the only
    # way back to that is closing a window whose date has passed — which needs
    # the id this read carries.
    it 'lists a window whose date has passed, and closes it' do
      window = create(:transfer, from_customer: user, transferable: card, to_phone: '13800000000')
      window.update_columns(expires_at: 1.hour.ago)

      get "/api/v3/store/customers/me/membership_cards/#{card.prefixed_id}/transfers", headers: headers

      expect(response.parsed_body['data'].first).to include('status' => 'expired')
      expect(card.reload.pending_transfer).to eq(window)

      delete "/api/v3/store/customers/me/membership_cards/#{card.prefixed_id}/transfers/#{window.prefixed_id}",
             headers: headers

      expect(response).to have_http_status(:ok)
      expect(window.reload).to be_canceled
      expect(card.reload.pending_transfer).to be_nil
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

    # The one read that has to happen before there is anybody to be signed in
    # as: a share link opened on a storefront that otherwise gates guests.
    it 'stays readable on a storefront that requires a sign-in' do
      store.default_channel.update!(preferred_storefront_access: 'login_required')

      get "/api/v3/store/membership_card_transfers/#{window.token}", headers: api_key_headers

      expect(response).to have_http_status(:ok)
    end

    it 'claims it, activating the card for whoever claimed it' do
      post "/api/v3/store/membership_card_transfers/#{window.token}/claims", headers: headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include('status' => 'accepted')
      expect(card.reload).to be_active
      expect(card.membership.customer).to eq(user)
      expect(user.reload.customer_groups).to include(group)

      # The claim is the activation, so what the answer hands back is the term
      # it just started — the client reads its end off this and does not ask
      # again.
      expect(response.parsed_body.dig('card', 'membership')).to include('status' => 'active')
      expect(response.parsed_body.dig('card', 'membership', 'ends_at')).
        to eq(card.membership.ends_at.iso8601)
    end

    # What the recipient reads beside the code: the rights the card carries, so
    # they know what they are claiming before they claim it, and the window it is
    # open in.
    it 'answers what the card is worth, and the window it is open in' do
      get "/api/v3/store/membership_card_transfers/#{window.token}", headers: api_key_headers

      expect(response.parsed_body['rights'].map { |right| right['type'] }).to eq(['exclusive_coupon'])
      expect(response.parsed_body['valid_from']).to be_present
      expect(response.parsed_body['expires_at']).to eq(window.expires_at.iso8601)
    end

    # 会员券 — a voucher is shared rather than addressed, so the phone is a hint
    # about where it went and not a permission: whoever holds the token claims
    # it, and the claim is what starts their term.
    it 'claims an open window for whoever holds its token' do
      open_card = create(:membership_card, customer: create(:customer), customer_group: group)
      open_window = create(:transfer, from_customer: open_card.customer, transferable: open_card, to_phone: nil)

      post "/api/v3/store/membership_card_transfers/#{open_window.token}/claims", headers: headers

      expect(response).to have_http_status(:created)
      expect(open_card.reload).to be_active
      expect(open_card.membership.customer).to eq(user)
    end

    it 'answers 404 for a token nobody holds' do
      get '/api/v3/store/membership_card_transfers/nothing-here', headers: api_key_headers

      expect(response).to have_http_status(:not_found)
    end

    # The primitive is shared, so a token belonging to another domain's transfer
    # in this same store is not this route's to read or claim.
    it 'answers 404 for a token of another domain' do
      stub_const('ForeignGiftCard', Class.new(Spree::GiftCard) do
        def self.polymorphic_name = name

        def on_transfer_given(_transfer); end
        def on_transfer_accepted(_transfer); end
        def on_transfer_canceled(_transfer); end
      end)

      elsewhere = create(:transfer, from_customer: create(:customer),
                                    transferable: ForeignGiftCard.create!(store: store, amount: 10),
                                    to_phone: '13800000000')

      get "/api/v3/store/membership_card_transfers/#{elsewhere.token}", headers: api_key_headers
      expect(response).to have_http_status(:not_found)

      post "/api/v3/store/membership_card_transfers/#{elsewhere.token}/claims", headers: headers
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
