module Spree
  module Memberships
    # The packet of coupons a tier grants, as both surfaces render it: the member
    # centre's 惊喜红包 panel, and the settlement page asking about a tier nobody
    # has bought yet.
    #
    # Read rather than stored — what one of its coupons is worth is
    # {Spree::Memberships::SurpriseCoupon}'s to say
    # (docs/plans/6.1-membership-tiers-and-rights.md).
    class SurprisePacket
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :right

      # The packet's coupons, in the order the right lists them.
      #
      # @return [Array<Spree::Memberships::SurpriseCoupon>]
      def coupons
        @coupons ||= right.coupon_entries.map do |promotion, settings|
          SurpriseCoupon.new(promotion: promotion, settings: settings)
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
