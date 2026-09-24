require 'spec_helper'

RSpec.describe Spree::Memberships::SurprisePacket do
  let(:store) { @default_store }
  let(:group) { create(:customer_group, store: store) }

  # A promotion shaped the way the client's cards are: money off over a basket,
  # a rate off one, or goods handed over rather than money.
  def money_off_promotion(amount, minimum: nil)
    promotion = create(:promotion, store: store, name: "减#{amount}")
    calculator = Spree::Calculator::FlatRate.new
    calculator.preferred_amount = amount
    Spree::Promotion::Actions::CreateAdjustment.create!(promotion: promotion, calculator: calculator)
    if minimum
      Spree::Promotion::Rules::ItemTotal.create!(promotion: promotion, preferred_amount_min: minimum)
    end
    promotion
  end

  def rate_off_promotion(percent)
    promotion = create(:promotion, store: store, name: "打#{percent}")
    calculator = Spree::Calculator::PercentOnLineItem.new
    calculator.preferred_percent = percent
    Spree::Promotion::Actions::CreateAdjustment.create!(promotion: promotion, calculator: calculator)
    promotion
  end

  def goods_promotion
    promotion = create(:promotion, store: store, name: '兑换')
    Spree::Promotion::Actions::CreateLineItems.create!(promotion: promotion)
    promotion
  end

  # What the tier says about one coupon: the copies it is handed over in, and
  # how often.
  def entry_for(promotion, **settings)
    { 'promotion_id' => promotion.prefixed_id, 'self_use' => 1, 'friend_use' => 0 }
      .merge(settings.transform_keys(&:to_s))
  end

  def right_granting(*entries)
    create(:surprise_right, customer_group: group, published: true,
                            preferences: { surprise_coupons: entries })
  end

  def packet_for(right)
    described_class.new(right: right, store: store)
  end

  describe 'what a coupon is worth' do
    it 'reads a flat amount off the promotion, with the basket it needs' do
      promotion = money_off_promotion(30, minimum: 199)

      coupon = packet_for(right_granting(entry_for(promotion))).coupons.first

      expect(coupon.discount_type).to eq('minus')
      expect(coupon.discount_minus).to eq(30)
      expect(coupon.discount_rate).to be_nil
      expect(coupon.limit_amount_min).to eq(199)
    end

    # The client prints 折 rather than the percentage: 15% off is 8.5折.
    it 'reads a rate off the promotion, as the number the client prints' do
      coupon = packet_for(right_granting(entry_for(rate_off_promotion(15)))).coupons.first

      expect(coupon.discount_type).to eq('discount')
      expect(coupon.discount_rate).to eq(8.5)
      expect(coupon.discount_minus).to be_nil
    end

    it 'reads goods handed over as an exchange rather than a reduction' do
      coupon = packet_for(right_granting(entry_for(goods_promotion))).coupons.first

      expect(coupon.discount_type).to eq('exchange')
      expect(coupon).to be_exchange
    end

    # A promotion nobody wrote a figure on is a coupon with no figure — not one
    # with a nought, which is what a customer would read as "nothing off".
    it 'claims no figure for a promotion it cannot read one off' do
      coupon = packet_for(right_granting(entry_for(create(:promotion, store: store)))).coupons.first

      expect(coupon.discount_type).to eq('minus')
      expect(coupon.discount_minus).to be_nil
      expect(coupon.money_value).to eq(0)
    end
  end

  describe 'what the packet is worth' do
    # Only money-off coupons have a figure nobody has to spend first: a rate and
    # an exchange are worth what the basket makes them worth.
    it 'counts every copy of every money-off coupon, and nothing else' do
      right = right_granting(
        entry_for(money_off_promotion(30), self_use: 2, friend_use: 1),
        entry_for(rate_off_promotion(15), self_use: 3, friend_use: 0),
        entry_for(money_off_promotion(10), self_use: 1, friend_use: 0)
      )

      expect(packet_for(right).total_money_sum).to eq(100)
    end

    it 'says so when one of its coupons is exchanged for goods' do
      right = right_granting(entry_for(money_off_promotion(30)), entry_for(goods_promotion))

      expect(packet_for(right)).to be_exchange
    end

    it 'lists the coupons in the order the tier wrote them' do
      first = money_off_promotion(30)
      second = rate_off_promotion(15)

      packet = packet_for(right_granting(entry_for(first), entry_for(second)))

      expect(packet.coupons.map { |coupon| coupon.promotion.id }).to eq([first.id, second.id])
    end
  end

  describe 'how a coupon is handed over' do
    it 'takes the copies and the cadence from the tier, not from the promotion' do
      right = right_granting(entry_for(money_off_promotion(30), self_use: 2, friend_use: 1,
                                                              grant_type: 'month', instruction: '每月一张'))

      coupon = packet_for(right).coupons.first

      expect(coupon.self_use).to eq(2)
      expect(coupon.friend_use).to eq(1)
      expect(coupon.grant_type).to eq('month')
      expect(coupon.instruction).to eq('每月一张')
    end

    it 'hands a coupon over once when the tier does not say otherwise' do
      coupon = packet_for(right_granting(entry_for(money_off_promotion(30)))).coupons.first

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

    it 'refuses an instruction that is not text' do
      right = build(:surprise_right, customer_group: group,
                                     preferences: {
                                       surprise_coupons: [entry_for(money_off_promotion(30), instruction: { a: 1 })]
                                     })

      expect(right).not_to be_valid
    end
  end
end
