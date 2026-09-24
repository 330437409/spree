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

  # The warning the buy page shows before it takes the money: what the terms a
  # customer already holds do to the package they are about to buy.
  describe 'GET /api/v3/store/membership_purchase_checks' do
    def get_checks(for_tier = tier)
      get '/api/v3/store/membership_purchase_checks', headers: headers, params: { tier_id: for_tier.prefixed_id }
    end

    it 'answers nothing to warn about for a customer who holds nothing' do
      get_checks

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['checks']).to eq([])
    end

    it 'names the term the purchase waits behind, and the instant it ends' do
      held = create(:membership, customer: user, customer_group: another_tier.customer_group,
                                 ends_at: 3.months.from_now)

      get_checks

      expect(response.parsed_body['checks']).to contain_exactly(
        'kind' => 'overlap',
        'tier_name' => held.customer_group.name,
        'held_until' => held.ends_at.iso8601
      )
    end

    # The card is refused at activation, and the money is already gone by then.
    it 'warns that a term held with no end refuses the purchase' do
      held = create(:membership, customer: user, customer_group: another_tier.customer_group, ends_at: nil)

      get_checks

      expect(response.parsed_body['checks']).to contain_exactly(
        'kind' => 'open_ended', 'tier_name' => held.customer_group.name, 'held_until' => nil
      )
    end

    it 'requires a signed-in customer' do
      get '/api/v3/store/membership_purchase_checks', headers: api_key_headers,
                                                      params: { tier_id: tier.prefixed_id }

      expect(response).to have_http_status(:unauthorized)
    end

    # The ladder is where the store is, so a package another store sells is not
    # one this customer is buying.
    it 'answers 404 for a tier of another store' do
      elsewhere = create(:membership_tier_setting, customer_group: create(:customer_group, store: create(:store)))

      get_checks(elsewhere)

      expect(response).to have_http_status(:not_found)
    end

    # A well-formed id of a tier this store no longer sells, so that what is
    # under test is the scoping rather than the prefix the id was minted with.
    it 'answers 404 for a tier nobody sells any more' do
      retired = create(:membership_tier_setting, customer_group: create(:customer_group, store: store))
      retired.destroy

      get_checks(retired)

      expect(response).to have_http_status(:not_found)
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

    # The 惊喜红包 panel, filled from the same payload the settlement page reads:
    # a kind that contributes something of its own contributes it here.
    it 'carries the surprise packet on the entry that grants it' do
      grant_packet(entry_for(money_off_promotion(30), self_use: 2))
      group.add_customers([user.id])

      get '/api/v3/store/customers/me/membership', headers: headers

      entry = response.parsed_body['sections']['rightsLevelSurpriseVoVos'].first
      expect(entry).to include('type' => 'surprise_red_envelope', 'is_have' => true)
      expect(entry['packet']).to include('total_money_sum' => '60.0', 'exchange' => false,
                                         'other_type' => '多张券')
      expect(entry['packet']['coupons'].first).to include('discount_type' => 'minus', 'discount_minus' => '30.0')
    end

    # A draft is a right nobody has published, so what it hands over is not a
    # promise yet. The ladder still lists it — that is what the panel is — and
    # the entry says nothing about what it gives, which is the same rule the
    # settlement page reads from the other side.
    it 'carries no packet for a right nobody has published' do
      grant_packet(entry_for(money_off_promotion(30)))
      Spree::MembershipRight.where(customer_group_id: group.id).update_all(published: false)
      group.add_customers([user.id])

      get '/api/v3/store/customers/me/membership', headers: headers

      entry = response.parsed_body['sections']['rightsLevelSurpriseVoVos'].first
      expect(entry).to include('published' => false)
      expect(entry).not_to have_key('packet')
    end
  end
  # The banner the member centre opens with: the picture of the customer's own
  # tier, and the tap targets over it.
  describe 'GET /api/v3/store/customers/me/membership_banner' do
    let(:banner) do
      create(:membership_banner, customer_group: group, name: '会员中心',
                                 areas: [{ 'area_rem' => 'left: 1rem;top: 2rem;width: 3rem;height: 1rem;',
                                           'link' => '/pages/member/index' }])
    end

    it 'answers the banner of the customer’s own tier' do
      banner
      group.add_customers([user.id])

      get '/api/v3/store/customers/me/membership_banner', headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('name' => '会员中心', 'pic' => banner.pic)
      expect(response.parsed_body['areas'].first).to include(
        'area_rem' => 'left: 1rem;top: 2rem;width: 3rem;height: 1rem;',
        'link' => '/pages/member/index'
      )
    end

    # Nothing to show is not an error: the page has no banner, and a body that
    # is not an object is how a client reads that.
    it 'answers nothing for a customer in no tier' do
      banner

      get '/api/v3/store/customers/me/membership_banner', headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_nil
    end

    it 'answers nothing for a tier nobody has set a banner for' do
      group.add_customers([user.id])

      get '/api/v3/store/customers/me/membership_banner', headers: headers

      expect(response.parsed_body).to be_nil
    end

    # The banner of another tier in this same store is not the customer's: they
    # hold a tier of their own, so this is the resolution rather than the
    # absence of a membership.
    it 'answers nothing for a banner of a tier they are not in' do
      banner
      their_group = create(:customer_group, store: store)
      create(:membership_tier_setting, customer_group: their_group, rank: 2)
      their_group.add_customers([user.id])

      get '/api/v3/store/customers/me/membership_banner', headers: headers

      expect(response.parsed_body).to be_nil
    end

    # A row written past the model — a console, an import — is left out of the
    # answer rather than rendered as a target nobody can place.
    it 'leaves out a target that is not a target at all' do
      banner
      group.add_customers([user.id])
      banner.update_column(:areas, '{"area_rem":"left: 1rem;"}')

      get '/api/v3/store/customers/me/membership_banner', headers: headers

      expect(response.parsed_body['areas']).to eq([])
    end
  end

  # What a tier says a member saves, read before anybody buys it — the buy page's
  # 每月约省 popup.
  describe 'GET /api/v3/store/membership_savings' do
    def get_savings(for_tier = tier)
      get '/api/v3/store/membership_savings', headers: headers, params: { tier_id: for_tier.prefixed_id }
    end

    it 'answers the four rows in order, the rules and the monthly figure' do
      tier.update!(preferences: { saving_order_title: '下单立省', saving_order_content: '会员价再低一点',
                                  saving_coupon_title: '专属券', saving_coupon_content: '每月领',
                                  saving_month_amount: 12.5, saving_rules: '以实际订单为准' })

      get_savings

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['rows'].map { |row| row['title'] }).
        to eq(['下单立省', '专属券', nil, nil])
      expect(response.parsed_body).to include('month_amount' => '12.5', 'rules' => '以实际订单为准')
    end

    # An unwritten popup is not a missing tier: the page opens it, prints what
    # there is and skips the rows nobody wrote.
    it 'answers blanks for a tier nobody has written for' do
      get_savings

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['rows'].length).to eq(4)
      expect(response.parsed_body['rows'].map { |row| row['title'] }).to all(be_nil)
      # Null rather than nought: a tier nobody has written for is not one whose
      # operator said a member saves nothing.
      expect(response.parsed_body['month_amount']).to be_nil
      expect(response.parsed_body['rules']).to be_nil
    end

    it 'requires a signed-in customer' do
      get '/api/v3/store/membership_savings', headers: api_key_headers, params: { tier_id: tier.prefixed_id }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'answers 404 for a tier of another store' do
      elsewhere = create(:membership_tier_setting, customer_group: create(:customer_group, store: create(:store)))

      get_savings(elsewhere)

      expect(response).to have_http_status(:not_found)
    end

    # A well-formed id of a tier this store no longer sells, so that what is
    # under test is the scoping rather than the prefix the id was minted with.
    it 'answers 404 for a tier nobody sells any more' do
      retired = create(:membership_tier_setting, customer_group: create(:customer_group, store: store))
      retired.destroy

      get_savings(retired)

      expect(response).to have_http_status(:not_found)
    end
  end

  # The packet of coupons a tier hands over, asked about a package the customer
  # has not bought yet — what the settlement page shows before the purchase.
  describe 'GET /api/v3/store/membership_surprise_packet' do
    def get_packet(for_tier = tier)
      get '/api/v3/store/membership_surprise_packet', headers: headers, params: { tier_id: for_tier.prefixed_id }
    end

    it 'answers the packet’s coupons, in the tier’s order, with what each is worth' do
      grant_packet(entry_for(money_off_promotion(30, minimum: 199), self_use: 2, friend_use: 1,
                                                              grant_type: 'month', instruction: '每月一张'))

      get_packet

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('total_money_sum' => '90.0', 'exchange' => false,
                                              'other_type' => '多张券')
      expect(response.parsed_body['coupons'].first).to include(
        'discount_type' => 'minus', 'discount_minus' => '30.0', 'discount_rate' => nil,
        'limit_amount_min' => '199.0', 'self_use' => 2, 'friend_use' => 1,
        'grant_type' => 'month', 'instruction' => '每月一张'
      )
    end

    # The read asks every coupon for its rate, so a packet holding one the goods
    # are handed over for has to answer rather than take the whole page down.
    it 'answers a packet holding a coupon that hands goods over' do
      grant_packet(entry_for(goods_promotion))

      get_packet

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('exchange' => true, 'total_money_sum' => '0.0')
      expect(response.parsed_body['coupons'].first).
        to include('discount_type' => 'exchange', 'discount_minus' => nil, 'discount_rate' => nil)
    end

    # Nothing to show is not an error, the same way a tier with no banner is not
    # one: the client opens the popup and prints no cards.
    it 'answers nothing for a tier that grants no packet' do
      get_packet

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_nil
    end

    it 'answers nothing for a packet nobody published' do
      grant_packet(entry_for(money_off_promotion(30)))
      Spree::MembershipRight.where(customer_group_id: group.id).update_all(published: false)

      get_packet

      expect(response.parsed_body).to be_nil
    end

    it 'requires a signed-in customer' do
      get '/api/v3/store/membership_surprise_packet', headers: api_key_headers, params: { tier_id: tier.prefixed_id }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'answers 404 for a tier of another store' do
      elsewhere = create(:membership_tier_setting, customer_group: create(:customer_group, store: create(:store)))

      get_packet(elsewhere)

      expect(response).to have_http_status(:not_found)
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

    # The wallet renders the window a card is inside, and a wallet of cards must
    # not pay for what only the voucher page shows: the rights the card carries
    # are that read's own.
    it 'leaves the voucher’s rights off the wallet’s window' do
      window = create(:transfer, from_customer: user, transferable: card, to_phone: nil)

      get '/api/v3/store/customers/me/membership_cards', headers: headers

      window_body = response.parsed_body['data'].find { |row| row['id'] == card.prefixed_id }['transfer']
      expect(window_body).to include('token' => window.token)
      expect(window_body).not_to have_key('rights')
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
    # open in. The list is this tier's *published* rights and nothing else — a
    # second tier's right and an unpublished one of this tier are both things a
    # claim would not hand over, and promising them here would be a promise the
    # redemption breaks.
    it 'answers what the card grants, and the window it is open in' do
      other_group = create(:customer_group, store: store)
      create(:membership_tier_setting, customer_group: other_group, rank: 2)
      create(:membership_right, customer_group: other_group)
      create(:entry_integral_right, customer_group: group, published: false)

      get "/api/v3/store/membership_card_transfers/#{window.token}", headers: api_key_headers

      expect(response.parsed_body['rights'].map { |right| right['type'] }).to eq(['exclusive_coupon'])
      expect(response.parsed_body['valid_from']).to be_present
      expect(response.parsed_body['expires_at']).to eq(window.expires_at.iso8601)
    end

    # The tier's rights as the operator arranged them, the way the ladder and the
    # rights page list them. The drag is what makes the difference visible: the
    # association's own order is the ladder's, and a reader that left it to the
    # database would answer whatever order the adapter happened to return.
    it 'lists the card’s rights in the ladder’s order' do
      create(:coupon_right, customer_group: group, published: true)
      dragged = create(:entry_integral_right, customer_group: group, published: true)
      dragged.move_to_top

      get "/api/v3/store/membership_card_transfers/#{window.token}", headers: api_key_headers

      ladder = Spree::MembershipRight.where(customer_group_id: group.id).order(:position, :id).
               map { |entry| entry.class.api_type }

      expect(response.parsed_body['rights'].map { |entry| entry['type'] }).to eq(ladder)
      expect(ladder.first).to eq('entry_integral')
    end

    # 已赠送 — the giver's own wallet keeps the window they opened, so the client
    # reads an accepted one beside the card's own status instead of taking the
    # claimer's term for the giver's own activation.
    it 'keeps the window on the giver’s card after it is claimed' do
      giver = create(:customer)
      giver_card = create(:membership_card, customer: giver, customer_group: group)
      open_window = create(:transfer, from_customer: giver, transferable: giver_card, to_phone: nil)

      post "/api/v3/store/membership_card_transfers/#{open_window.token}/claims", headers: headers

      giver_headers = api_key_headers.merge(
        'Authorization' => "Bearer #{Spree::Api::V3::TestingSupport.generate_jwt(giver)}"
      )
      get '/api/v3/store/customers/me/membership_cards', headers: giver_headers

      row = response.parsed_body['data'].first
      expect(row['transfer']).to include('status' => 'accepted', 'token' => open_window.token)
      expect(row['membership']).to be_present
    end

    # 会员券 — a voucher is shared rather than addressed: the giver opens a window
    # that names nobody, and whoever holds its token claims it. The empty field a
    # form submits when nobody fills it in is no phone at all, which is the same
    # open window — and the buyer stays the buyer while the term is the claimer's.
    it 'gives a card without a phone and hands it to whoever claims the token' do
      giver = create(:customer)
      giver_card = create(:membership_card, customer: giver, customer_group: group)
      giver_headers = api_key_headers.merge(
        'Authorization' => "Bearer #{Spree::Api::V3::TestingSupport.generate_jwt(giver)}"
      )

      post "/api/v3/store/customers/me/membership_cards/#{giver_card.prefixed_id}/transfers",
           headers: giver_headers, params: { to_phone: '', expires_at: 1.week.from_now.iso8601 }

      expect(response).to have_http_status(:created)
      token = response.parsed_body['token']

      post "/api/v3/store/membership_card_transfers/#{token}/claims", headers: headers

      expect(response).to have_http_status(:created)
      expect(giver_card.reload).to be_active
      expect(giver_card.membership.customer).to eq(user)
      expect(giver_card.customer).to eq(giver)
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
