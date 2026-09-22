module Spree
  module CouponCampaigns
    # 新人券: for an account that has just been made, and only for as long as
    # "just" means. The window is the campaign's own setting rather than a
    # constant, because how long a new customer stays new is the operator's
    # answer and not this gem's.
    class NewCustomer < Spree::CouponCampaign
      preference :within_days, :integer, default: 30

      def eligible_for?(customer)
        return false if customer.nil? || customer.created_at.nil?

        customer.created_at >= preferred_within_days.to_i.days.ago
      end
    end
  end
end
