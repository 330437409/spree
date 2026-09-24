module Spree
  module Memberships
    # One member's annual gift, as the member centre renders it: the coupons the
    # gift offers, which of them they have already taken this year, and what is
    # left of both the year's allowance and the gift itself.
    #
    # Read rather than stored. A claim is a `Spree::Grant` of
    # {Spree::Memberships::YearGiftClaim}, so the numbers follow from the rows
    # and nothing has to be reset when a year turns: the year is part of the
    # claim's key and of this read's window
    # (docs/plans/6.1-membership-tiers-and-rights.md).
    class YearGift
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :right
      attribute :customer
      attribute :store

      # How this gift is claimed: a coupon handed over here, or a physical gift
      # whose claim this API does not serve.
      #
      # @return [String]
      def mode
        right.preferred_gift_mode
      end

      # How many times the member may still claim this year — the client's
      # `canCount`, which reads 领取完毕 once it reaches zero.
      #
      # @return [Integer]
      def can_count
        [limit - claims.size, 0].max
      end

      # Whether the year has more claims than its allowance. Read rather than
      # clamped, so a caller that has already written its own claim can ask
      # whether that claim was one too many — which is how a claim that raced
      # another stands down.
      #
      # @return [Boolean]
      def over_allowance?
        claims.size > limit
      end

      # How much of the gift is still unclaimed — the client's `usableNum`. It
      # is a second number because the two disagree: a member whose allowance is
      # spent while coupons remain has claimed everything they may this year,
      # and the button says so rather than offering what they cannot have.
      #
      # @return [Integer]
      def usable_num
        coupons.count { |coupon| !coupon.claimed? }
      end

      # The gift's coupons, in the order claims take them, each knowing whether
      # this member has taken it this year.
      #
      # @return [Array<Spree::Memberships::YearGift::Coupon>]
      def coupons
        @coupons ||= right.gift_promotions.map do |promotion|
          Coupon.new(promotion: promotion, claimed: claimed_promotion_ids.include?(promotion.id.to_s))
        end
      end

      # The coupon a claim takes when the caller names none: the first of the
      # gift's own order the member has not taken yet.
      #
      # @return [Spree::Memberships::YearGift::Coupon, nil]
      def next_coupon
        coupons.detect { |coupon| !coupon.claimed? }
      end

      # @param promotion_id [String] a promotion's prefixed id
      # @return [Spree::Memberships::YearGift::Coupon, nil] nil when that
      #   promotion is not one of this gift's
      def coupon_for(promotion_id)
        coupons.detect { |coupon| coupon.promotion.prefixed_id == promotion_id.to_s }
      end

      # This year's claims for this tier's gift. Scoped to the tier rather than
      # to the right row, which an operator replaces: the allowance belongs to
      # the tier, so replacing its gift does not hand the year back.
      #
      # @return [Array<Spree::Grant>]
      def claims
        return @claims if defined?(@claims)

        @claims = Spree::Grant.
                  where(kind: YearGiftClaim.api_type, customer_id: customer&.id, source: right.customer_group).
                  where(granted_at: year_window).to_a
      end

      # The year the allowance is counted for, in the store's own calendar: an
      # allowance is a fact of the merchant's year rather than the server's.
      #
      # @return [Integer]
      def year
        @year ||= SpreeMemberships.today_in(store).year
      end

      private

      def limit
        right.preferred_yearly_limit.to_i
      end

      # The promotions this member has taken this year, read off the rows rather
      # than taken apart from their keys: the key is what makes a claim
      # idempotent, and how it is spelled is the kind's business.
      #
      # @return [Array<String>]
      def claimed_promotion_ids
        @claimed_promotion_ids ||= claims.map { |grant| grant.metadata['promotion_id'].to_s }
      end

      # Midnight to midnight of the store's own year — which is what makes a
      # claim taken on the first of January belong to the new year for a store
      # whose midnight is not the server's.
      #
      # @return [Range<Time>]
      def year_window
        zone = SpreeMemberships.zone_for(store)

        zone.local(year, 1, 1)..zone.local(year + 1, 1, 1)
      end

      # One coupon of a gift, as this member stands with it.
      class Coupon
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :promotion
        attribute :claimed, :boolean, default: false

        # @return [Boolean]
        def claimed?
          claimed
        end
      end
    end
  end
end
