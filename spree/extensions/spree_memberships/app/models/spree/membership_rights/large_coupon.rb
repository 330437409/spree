module Spree
  module MembershipRights
    # A big-face coupon, exchanged upwards rather than handed over.
    class LargeCoupon < Spree::MembershipRight
      include Spree::MembershipRights::HandsOverCoupon

      # 兑换大额券
      def self.presents_as
        'largeCouponInfo'
      end
    end
  end
end
