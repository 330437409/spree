module Spree
  module MembershipRights
    # A coupon only this tier holds. What it grants is issued by the coupon
    # wallet, and the occasion that issues it names the coupon.
    class ExclusiveCoupon < Spree::MembershipRight
      include Spree::MembershipRights::HandsOverCoupon

      # 专属红包 — the panel the exclusive coupons are listed in.
      def self.presents_as
        'vipCouponInfoVo'
      end
    end
  end
end
