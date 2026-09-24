module Spree
  module Api
    module V3
      # One coupon of a tier's packet, as the client's card renders it: what it
      # is worth, how many of it the member is handed, and whether it arrives
      # every month.
      #
      # Deliberately not a `BaseSerializer`: a coupon of a packet is a reading of
      # a promotion rather than a record of its own, so there is no id and
      # nothing to update. A figure the promotion does not state — a rate, a
      # threshold, a money-off amount — is answered null rather than zero, so a
      # card with nothing to say says nothing.
      class SurprisePacketCouponSerializer
        include Alba::Resource
        include Typelizer::DSL
        include MembershipMoney

        typelize promotion_id: :string,
                 discount_type: [:string, enum: Spree::Memberships::SurpriseCoupon::DISCOUNT_TYPES],
                 discount_minus: 'string | null', discount_rate: 'string | null',
                 limit_amount_min: 'string | null', instruction: 'string | null',
                 self_use: :number, friend_use: :number,
                 grant_type: [:string, enum: Spree::MembershipRights::SurpriseRedEnvelope::GRANT_TYPES]

        attribute(:promotion_id) { |coupon| coupon.promotion.prefixed_id }
        attribute(:discount_type) { |coupon| coupon.discount_type }
        attribute(:discount_minus) { |coupon| decimal(coupon.discount_minus) }
        attribute(:discount_rate) { |coupon| decimal(coupon.discount_rate) }
        attribute(:limit_amount_min) { |coupon| decimal(coupon.limit_amount_min) }
        attribute(:instruction) { |coupon| coupon.instruction }
        attribute(:self_use) { |coupon| coupon.self_use }
        attribute(:friend_use) { |coupon| coupon.friend_use }
        attribute(:grant_type) { |coupon| coupon.grant_type }
      end
    end
  end
end
