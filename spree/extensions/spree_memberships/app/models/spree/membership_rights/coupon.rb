module Spree
  module MembershipRights
    # An ordinary coupon the tier carries. Shares the exclusive coupons' panel,
    # because the client does not tell them apart.
    class Coupon < Spree::MembershipRight
      def self.presents_as
        'vipCouponInfoVo'
      end
    end
  end
end
