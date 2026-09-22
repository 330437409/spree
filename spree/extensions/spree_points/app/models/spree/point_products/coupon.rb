module Spree
  module PointProducts
    # A good that issues a coupon: the row points at the coupon wallet's
    # campaign, and that plan issues what the redemption earns
    # (docs/plans/6.1-coupon-wallet.md).
    class Coupon < Spree::PointProduct
      belongs_to :coupon_campaign, class_name: 'Spree::CouponCampaign', optional: true

      # The campaign is a forward reference: the coupon wallet owns that table and it is not built yet, so the column is validated rather than the association — which would resolve a class that does not exist.
      validates :coupon_campaign_id, presence: true
    end
  end
end
