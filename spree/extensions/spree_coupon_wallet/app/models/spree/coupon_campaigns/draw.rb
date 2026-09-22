module Spree
  module CouponCampaigns
    # The plain one: anybody inside the window may take a coupon, up to the
    # campaign's own limit per customer.
    class Draw < Spree::CouponCampaign
    end
  end
end
