require 'spec_helper'

RSpec.describe Spree::Memberships::SurprisePacket do
  let(:store) { @default_store }
  let(:group) { create(:customer_group, store: store) }

  def packet_for(right)
    described_class.new(right: right)
  end

  # One coupon, over a packet of its own: a group carries one right of a kind, so
  # a case reading several coupons needs several tiers.
  def coupon_for(promotion, **settings)
    group = create(:customer_group, store: store)
    right = create(:surprise_right, customer_group: group, published: true,
                                    preferences: { surprise_coupons: [entry_for(promotion, **settings)] })

    packet_for(right).coupons.first
  end

  describe 'what a coupon is worth' do
    it 'reads a flat amount off the promotion, with the basket it needs' do
      promotion = money_off_promotion(30, minimum: 199)

      coupon = packet_for(grant_packet(entry_for(promotion))).coupons.first

      expect(coupon.discount_type).to eq('minus')
      expect(coupon.discount_minus).to eq(30)
      expect(coupon.discount_rate).to be_nil
      expect(coupon.limit_amount_min).to eq(199)
    end

    # The client prints 折 rather than the percentage: 15% off is 8.5折.
    it 'reads a rate off the promotion, as the number the client prints' do
      coupon = packet_for(grant_packet(entry_for(rate_off_promotion(15)))).coupons.first

      expect(coupon.discount_type).to eq('discount')
      expect(coupon.discount_rate).to eq(8.5)
      expect(coupon.discount_minus).to be_nil
    end

    it 'reads goods handed over as an exchange rather than a reduction' do
      coupon = packet_for(grant_packet(entry_for(goods_promotion))).coupons.first

      expect(coupon.discount_type).to eq('exchange')
      expect(coupon).to be_exchange
    end

    # The read asks every coupon for its rate, whether or not it has one, so a
    # coupon with no calculator must answer rather than take the page down: the
    # action that hands goods over carries none.
    it 'answers an exchange coupon without asking for a calculator it has none of' do
      coupon = packet_for(grant_packet(entry_for(goods_promotion))).coupons.first

      expect(coupon.discount_rate).to be_nil
      expect(coupon.discount_minus).to be_nil
      expect(coupon.limit_amount_min).to be_nil
      expect(coupon.money_value).to eq(0)
    end

    # A promotion nobody wrote a figure on is a coupon with no figure and no
    # type — not one claiming a reduction of nothing, which is what a customer
    # would read as "减 ¥0".
    it 'claims no figure and no type for a promotion it cannot read one off' do
      coupon = packet_for(grant_packet(entry_for(create(:promotion, store: store)))).coupons.first

      expect(coupon.discount_type).to be_nil
      expect(coupon.discount_minus).to be_nil
      expect(coupon.money_value).to eq(0)
    end

    # A calculator's amount is in a currency of its own, and the store prints its
    # own: a figure in another one is not a figure this card can state. The
    # comparison ignores case, the way the calculator's own `compute` does.
    it 'claims no figure for a coupon priced in another currency' do
      coupon = coupon_for(money_off_promotion(30, currency: 'cny'))

      expect(coupon.discount_type).to be_nil
      expect(coupon.money_value).to eq(0)
    end

    it 'states the figure of one priced in the currency being shopped in' do
      expect(coupon_for(money_off_promotion(30, currency: 'usd')).discount_minus).to eq(30)
    end

    it 'claims no type for free shipping, whose action carries no calculator' do
      coupon = packet_for(grant_packet(entry_for(create(:free_shipping_promotion, store: store)))).coupons.first

      expect(coupon.discount_type).to be_nil
      expect(coupon.money_value).to eq(0)
    end

    # A ladder is not a figure, and neither is nought off or everything off: what
    # the card cannot state, it does not claim.
    it 'claims no rate for a ladder, and none for nought off or everything off' do
      ladder = create(:promotion, store: store, name: '阶梯')
      Spree::Promotion::Actions::CreateAdjustment.create!(
        promotion: ladder, calculator: Spree::Calculator::TieredPercent.new(preferred_base_percent: 10)
      )

      expect(coupon_for(ladder).discount_type).to be_nil
      [0, 100].each { |percent| expect(coupon_for(rate_off_promotion(percent)).discount_type).to be_nil }
    end
  end

  describe 'what the packet is worth' do
    # Only money-off coupons have a figure nobody has to spend first: a rate and
    # an exchange are worth what the basket makes them worth.
    it 'counts every copy of every money-off coupon, and nothing else' do
      right = grant_packet(
        entry_for(money_off_promotion(30), self_use: 2, friend_use: 1),
        entry_for(rate_off_promotion(15), self_use: 3, friend_use: 0),
        entry_for(money_off_promotion(10), self_use: 1, friend_use: 0)
      )

      expect(packet_for(right).total_money_sum).to eq(100)
    end

    it 'says so when one of its coupons is exchanged for goods' do
      right = grant_packet(entry_for(money_off_promotion(30)), entry_for(goods_promotion))

      expect(packet_for(right)).to be_exchange
    end

    it 'lists the coupons in the order the tier wrote them' do
      first = money_off_promotion(30)
      second = rate_off_promotion(15)

      packet = packet_for(grant_packet(entry_for(first), entry_for(second)))

      expect(packet.coupons.map { |coupon| coupon.promotion.id }).to eq([first.id, second.id])
    end
  end

  describe 'how a coupon is handed over' do
    it 'takes the copies and the cadence from the tier, not from the promotion' do
      right = grant_packet(entry_for(money_off_promotion(30), self_use: 2, friend_use: 1,
                                                              grant_type: 'month', instruction: '每月一张'))

      coupon = packet_for(right).coupons.first

      expect(coupon.self_use).to eq(2)
      expect(coupon.friend_use).to eq(1)
      expect(coupon.grant_type).to eq('month')
      expect(coupon.instruction).to eq('每月一张')
    end

    it 'hands a coupon over once when the tier does not say otherwise' do
      coupon = packet_for(grant_packet(entry_for(money_off_promotion(30)))).coupons.first

      expect(coupon.grant_type).to eq('once')
      expect(coupon.instruction).to be_nil
    end
  end

  describe 'what it refuses' do
    it 'refuses a packet with no coupons in it' do
      expect(build(:surprise_right, customer_group: group, preferences: { surprise_coupons: [] })).not_to be_valid
    end

    # A packet nothing can be handed over from is an operator error: a pool in
    # another store's promotion is a code this tier must not hand out.
    it 'refuses a coupon drawing on another store’s promotion' do
      elsewhere = create(:promotion, store: create(:store))

      right = build(:surprise_right, customer_group: group,
                                     preferences: { surprise_coupons: [entry_for(elsewhere)] })

      expect(right).not_to be_valid
    end

    it 'refuses a cadence it does not know, and a count nobody can hold' do
      promotion = money_off_promotion(30)

      expect(build(:surprise_right, customer_group: group,
                                    preferences: { surprise_coupons: [entry_for(promotion, grant_type: 'weekly')] })).
        not_to be_valid
      expect(build(:surprise_right, customer_group: group,
                                    preferences: { surprise_coupons: [entry_for(promotion, self_use: -1)] })).
        not_to be_valid
    end

    it 'refuses a coupon that does not say how many the member gets' do
      entry = entry_for(money_off_promotion(30)).except('self_use')

      expect(build(:surprise_right, customer_group: group,
                                    preferences: { surprise_coupons: [entry] })).not_to be_valid
    end

    it 'refuses a packet listing the same coupon twice' do
      promotion = money_off_promotion(30)
      entries = [entry_for(promotion), entry_for(promotion, self_use: 2)]

      expect(build(:surprise_right, customer_group: group,
                                    preferences: { surprise_coupons: entries })).not_to be_valid
    end

    # Retiring a right must not need the promotion it names to still exist. The
    # declared defaults are filled in when a row is loaded, so a guard on the
    # attribute's dirty flag would refuse this on a fresh row and allow the very
    # same write on a second attempt.
    it 'retires a right whose promotion is gone' do
      promotion = money_off_promotion(30)
      right = grant_packet(entry_for(promotion))
      promotion.destroy

      expect(right.reload.update(published: false)).to be(true)
      expect(right.reload).not_to be_published
    end

    it 'refuses an instruction that is not text' do
      right = build(:surprise_right, customer_group: group,
                                     preferences: {
                                       surprise_coupons: [entry_for(money_off_promotion(30), instruction: { a: 1 })]
                                     })

      expect(right).not_to be_valid
    end
  end
end
