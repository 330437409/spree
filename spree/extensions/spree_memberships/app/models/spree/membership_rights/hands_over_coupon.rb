module Spree
  module MembershipRights
    # A kind that hands a coupon to whoever enters the tier — the `giftCoupon`
    # half of the client's 恭喜升级 bag.
    #
    # It names the promotion rather than a code: the code is drawn from the
    # promotion's pool when the card is activated, which is what lets two members
    # entering on the same day hold different codes.
    module HandsOverCoupon
      extend ActiveSupport::Concern

      # @return [String, nil] the promotion a coupon is drawn from
      def entry_coupon
        preferred_promotion_id.presence
      end
    end
  end
end
