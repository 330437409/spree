# A promotion shaped the way an operator's cards are, and what a tier says about
# it. The packet is read on two surfaces, so how one is built lives in one place:
# the entry's shape is the thing a model spec and a request spec must agree about.
module SurprisePacketHelpers
  # @return [Spree::Promotion] the shape the client prints as 满199减30
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

  # @return [Spree::Promotion] the shape the client prints as 8.5折
  def rate_off_promotion(percent)
    promotion = create(:promotion, store: store, name: "打#{percent}")
    calculator = Spree::Calculator::PercentOnLineItem.new
    calculator.preferred_percent = percent
    Spree::Promotion::Actions::CreateAdjustment.create!(promotion: promotion, calculator: calculator)
    promotion
  end

  # @return [Spree::Promotion] one that hands goods over rather than money
  def goods_promotion
    promotion = create(:promotion, store: store, name: '兑换')
    Spree::Promotion::Actions::CreateLineItems.create!(promotion: promotion)
    promotion
  end

  # What a tier says about one coupon: the copies it is handed over in, and how
  # often.
  #
  # @return [Hash]
  def entry_for(promotion, **settings)
    { 'promotion_id' => promotion.prefixed_id, 'self_use' => 1, 'friend_use' => 0 }
      .merge(settings.transform_keys(&:to_s))
  end

  # The tier's right, carrying the packet it lists. The operator's words for a
  # packet with no money to quote travel with it, since the read answers them.
  #
  # @return [Spree::MembershipRights::SurpriseRedEnvelope]
  def grant_packet(*entries, other_type: '多张券')
    create(:surprise_right, customer_group: group, published: true,
                            preferences: { surprise_coupons: entries, surprise_other_type: other_type })
  end
end

RSpec.configure do |config|
  config.include SurprisePacketHelpers
end
