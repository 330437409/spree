require 'rails/engine'

module SpreeCouponWallet
  class Engine < Rails::Engine
    engine_name 'spree_coupon_wallet'

    # Registered after initialization because core assigns the registry in its
    # own initializer, and engine callbacks run in load order.
    config.after_initialize do
      Spree.grant_kinds << Spree::Coupons::Holding

      [
        Spree::CouponCampaigns::Draw,
        Spree::CouponCampaigns::NewCustomer,
        Spree::CouponCampaigns::SiteScoped
      ].each do |kind|
        SpreeCouponWallet.coupon_campaign_types << kind unless SpreeCouponWallet.coupon_campaign_types.include?(kind)
      end
    end
  end
end
