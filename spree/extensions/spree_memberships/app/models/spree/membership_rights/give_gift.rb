module Spree
  module MembershipRights
    # The annual gift — 开卡送酒. What it gives is looked up per tier, which is
    # why the panel it presents in is paged by tier name.
    #
    # A gift comes in two modes, and only one of them is claimed here. A
    # `coupon` gift draws on its own promotions: the member claims, and a claim
    # hands one coupon over — which is why the gift carries a list rather than a
    # single promotion, and why it is counted both as an allowance and as
    # coupons still to take. A `logistics` gift is a physical one, and its claim
    # screen belongs to the prize module this plan excludes: the right is here,
    # the frame that displays it is not (docs/plans/6.1-membership-tiers-and-rights.md).
    class GiveGift < Spree::MembershipRight
      # The gift as a value's own vocabulary. Only the mode decides which of
      # them a claim expects.
      MODES = %w[coupon logistics].freeze

      # The coupons a claim draws from, in the order claims take them, as the
      # prefixed ids the API hands out and takes back — the same spelling the
      # entry coupon uses, one tier further out.
      preference :gift_promotion_ids, :array, default: []
      # How many times a member may claim in one year — the client's
      # `limitCount`, which it counts `yetCount` against.
      preference :yearly_limit, :integer, default: 1
      preference :gift_mode, :string, default: 'coupon', in: MODES

      validate :yearly_limit_must_allow_a_claim, if: -> { new_record? || will_save_change_to_preferences? }
      validate :gift_mode_must_be_known, if: -> { new_record? || will_save_change_to_preferences? }
      validate :coupon_gift_must_offer_a_coupon, if: -> { new_record? || will_save_change_to_preferences? }
      validate :gift_promotions_must_belong_to_the_store, if: -> { new_record? || will_save_change_to_preferences? }

      # 开卡送酒
      def self.presents_as
        'yearGiftLevelSettingVos'
      end

      # The coupons this gift offers, in the order claims take them.
      #
      # @return [Array<Spree::Promotion>]
      def gift_promotions
        promotions_for(preferred_gift_promotion_ids)
      end

      # @return [Boolean] whether a claim here hands a coupon over
      def coupon_gift?
        preferred_gift_mode == 'coupon'
      end

      # @return [Spree::Memberships::YearGift, nil] nil for a delivered gift: it
      #   is not claimed here, so it has no state of its own to answer with
      def member_payload(customer:, store:)
        return nil unless coupon_gift?

        Spree::Memberships::YearGift.new(right: self, customer: customer, store: store)
      end

      private

      # A limit nothing can be claimed against and a mode no claim understands
      # are both operator errors, and both are refused where they are written.
      def yearly_limit_must_allow_a_claim
        return if preferred_yearly_limit.to_i >= 1

        errors.add(:preferences, :invalid)
      end

      def gift_mode_must_be_known
        return if MODES.include?(preferred_gift_mode)

        errors.add(:preferences, :invalid)
      end

      # A coupon gift with no coupons is a gift nothing can be claimed from: the
      # panel would report an allowance no claim can spend, so it is refused
      # where an operator writes it rather than where a member meets it.
      def coupon_gift_must_offer_a_coupon
        return unless coupon_gift?
        return if Array(preferred_gift_promotion_ids).present?

        errors.add(:preferences, :invalid)
      end

      # The entry coupon's own check, over a list: a pool in another store's
      # promotion is a code this tier must not draw. Read where the row is
      # written and while the preferences are being written — never on an
      # ordinary save, so a right whose promotion has since gone can still be
      # retired.
      def gift_promotions_must_belong_to_the_store
        return if Array(preferred_gift_promotion_ids).all? { |id| promotion_of_this_store?(id) }

        errors.add(:preferences, :invalid)
      end
    end
  end
end
