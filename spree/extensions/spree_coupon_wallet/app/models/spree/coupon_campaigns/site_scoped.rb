module Spree
  module CouponCampaigns
    # A site's own handout — 注册到店: the coupon belongs to one site, and only
    # a request shopping at that site is offered it.
    #
    # The site is a preference holding the seller's prefixed id, because that
    # is the identifier the API hands out and takes back, and the seller may
    # belong to a gem that is not installed.
    class SiteScoped < Spree::CouponCampaign
      preference :seller_id, :string, nullable: true

      def eligible_for?(_customer)
        site = preferred_seller_id.presence
        return false if site.nil?

        Spree::Current.seller&.prefixed_id == site
      end
    end
  end
end
