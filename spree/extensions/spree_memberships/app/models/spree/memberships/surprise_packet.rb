module Spree
  module Memberships
    # The packet of coupons a tier grants, as both surfaces render it: the member
    # centre's 惊喜红包 panel, and the settlement page asking about a tier nobody
    # has bought yet.
    #
    # Read rather than stored, and its coupons are *read* rather than configured:
    # what one is worth comes from the promotion it draws on, so an operator who
    # edits a promotion does not have to remember a second number. What the right
    # does own is how many of each a member is handed and how often — the part no
    # promotion knows (docs/plans/6.1-membership-tiers-and-rights.md).
    class SurprisePacket
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :right
      attribute :store

      # The packet's coupons, in the order the right lists them.
      #
      # @return [Array<Spree::Memberships::SurpriseCoupon>]
      def coupons
        @coupons ||= right.coupon_promotions.map do |promotion|
          SurpriseCoupon.new(promotion: promotion, settings: right.coupon_settings(promotion))
        end
      end

      # What the packet is worth in money: each flat-amount coupon times the
      # copies the packet grants of it, and nothing for the percentage and the
      # exchange ones, whose worth no operator can state in advance.
      #
      # @return [BigDecimal]
      def total_money_sum
        coupons.sum(0.to_d, &:money_value)
      end

      # @return [Boolean] whether any coupon is exchanged for goods rather than
      #   taken off a price, which is what the page says instead of 减
      def exchange?
        coupons.any?(&:exchange?)
      end

      # @return [String, nil] the operator's own words for a packet with no money
      #   to quote
      def other_type
        right.preferred_surprise_other_type.presence
      end
    end
  end
end
