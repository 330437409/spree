module Spree
  module Api
    module V3
      # A coupon the customer holds: the code they show or type, what state
      # it is in, when it lapses, and the promotion it is worth.
      #
      # The promotion rides along as its own serializer rather than as a hash
      # built here, and a coupon's discount is deliberately not spelled out:
      # what a coupon is worth is the promotion's own business and the cart
      # is where it is priced.
      class CouponHoldingSerializer < BaseSerializer
        typelize code: :string, status: :string, source: :string,
                 expires_at: 'string | null', campaign_id: 'string | null',
                 promotion: 'Record<string, unknown> | null'

        attributes :code, :source

        attribute(:status) { |holding| holding.display_status }
        attribute(:expires_at) { |holding| holding.expires_at&.iso8601 }
        attribute(:campaign_id) { |holding| holding.campaign&.prefixed_id }
        attribute(:promotion) do |holding|
          Spree::Api::V3::CouponPromotionSerializer.new(
            holding.coupon_code.promotion, params: params
          ).to_h
        end
      end
    end
  end
end
