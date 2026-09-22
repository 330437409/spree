module Spree
  module PointProducts
    # A good that issues a coupon.
    #
    # The campaign column is validated rather than its association: the wallet
    # that owns that table is a later plan, and a `belongs_to` would resolve a
    # class that does not exist yet
    # (docs/plans/6.1-coupon-wallet.md).
    class Coupon < Spree::PointProduct
      issues :coupon_campaign_id
    end
  end
end
