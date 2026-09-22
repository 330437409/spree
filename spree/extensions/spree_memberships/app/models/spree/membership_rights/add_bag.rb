module Spree
  module MembershipRights
    # The tier may buy the member add-on pack — 会员加量包, a bundle of
    # promotional coupons. The purchase is the scenario order's `rights` kind;
    # this right is the whole of this gem's part in it, and its presence on a
    # tier is the condition.
    class AddBag < Spree::MembershipRight
      # 会员加量包
      def self.presents_as
        'rightsCouponsVo'
      end
    end
  end
end
