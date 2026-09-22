require 'spree_core'
require 'spree_grants'
require 'spree_coupon_wallet/engine'

# A coupon a customer holds: what the mini program's wallet lists, gives away
# and applies. Spree's own model is the inverse of that — a `Spree::CouponCode`
# belongs to a promotion and binds to a cart, never to a customer — so this gem
# adds the holding beside the code, and a campaign for the ways one arrives
# (docs/plans/6.1-coupon-wallet.md).
module SpreeCouponWallet
  # The ways a campaign hands a coupon over, each a subclass of
  # `Spree::CouponCampaign` that declares its own settings and its own
  # eligibility. A registry rather than a validated string, so a kind is a
  # class a picker can list and another gem can add one without editing this
  # one.
  #
  # Filled by the engine after initialization, because a subclass may not exist
  # yet when this file loads.
  def self.coupon_campaign_types
    @coupon_campaign_types ||= []
  end
end
