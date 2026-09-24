module Spree
  module Memberships
    # 立即领取 — the annual gift, claimed.
    #
    # A claim draws one coupon of the gift, hands it over through the wallet and
    # records the claim as a `Spree::Grant` of {Spree::Memberships::YearGiftClaim},
    # all of it in one transaction: a claim whose coupon could not be issued is
    # not a claim, so the member keeps the allowance and may ask again.
    #
    # The two rows share one idempotency key — the member, the right, the year
    # and the coupon — so a retried request is answered the coupon the first
    # call issued rather than a second one out of the pool, and the year's
    # allowance is only spent by a claim that is not this one already
    # (docs/plans/6.1-membership-tiers-and-rights.md).
    class ClaimYearGift
      prepend Spree::ServiceModule::Base

      # @param right [Spree::MembershipRight] the tier's own gift
      # @param customer [Object] the member claiming it
      # @param promotion_id [String, nil] which of the gift's coupons, by its
      #   prefixed id; the first one they have not taken when omitted
      # @param store [Spree::Store, nil]
      # @return [Spree::ServiceModule::Result] value is the coupon holding
      def call(right:, customer:, promotion_id: nil, store: nil)
        store ||= Spree::Current.store

        return failure(right, :not_a_gift) unless right.is_a?(Spree::MembershipRights::GiveGift)
        return failure(right, Spree.t('memberships.errors.gift_not_coupons')) unless right.coupon_gift?
        return failure(right, Spree.t('memberships.errors.gift_not_the_tiers')) unless holds_tier?(right, customer, store)

        gift = right.member_payload(customer: customer, store: store)
        promotion = promotion_id.present? ? gift.coupon_for(promotion_id)&.promotion : gift.next_promotion

        return failure(right, Spree.t('memberships.errors.gift_coupon_unknown')) if promotion.nil? && promotion_id.present?
        return failure(right, Spree.t('memberships.errors.gift_claimed')) if promotion.nil?

        # A replay is answered the coupon it already issued, so the allowance is
        # only spent by a claim the member has not made yet.
        if gift.claim_for(promotion).nil? && gift.can_count.zero?
          return failure(right, Spree.t('memberships.errors.gift_allowance_spent'))
        end

        record(gift, right, promotion, customer, store)
      end

      private

      # A claim belongs to a tier, so it is the member's own tier that may claim
      # it — the fact the panel marks as `is_have` and the reason a gift of a
      # tier somebody is not on is not theirs to take.
      def holds_tier?(right, customer, store)
        tier = Spree::MembershipTierSetting.for_store(store).for_customer(customer)

        tier.present? && tier.customer_group_id == right.customer_group_id
      end

      # @return [Spree::ServiceModule::Result] value is the coupon holding
      def record(gift, right, promotion, customer, store)
        result = nil

        Spree::Grant.transaction(requires_new: true) do
          claim = Spree::Grants.grant!(
            kind: YearGiftClaim,
            customer: customer,
            source: right,
            store: store,
            context: { customer: customer, right: right, promotion: promotion, year: gift.year },
            metadata: { 'promotion_id' => promotion.id.to_s }
          )

          if claim.failure?
            result = failure(right, claim.error)
            raise ActiveRecord::Rollback
          end

          issued = issue(claim.value, right, promotion, customer, store)
          if issued.failure?
            result = failure(right, issued.error)
            raise ActiveRecord::Rollback
          end

          # What the claim released, on the claim itself: the coupon is the
          # wallet's row, and this is the pair an operator reads.
          claim.value.update!(issued: issued.value)

          # A claim is paid the moment it is written, so it is consumed here
          # rather than left standing as a debt. A replay finds it consumed.
          consume(claim.value)

          result = success(issued.value)
        end

        result
      end

      # The wallet issues under the claim's own key, so a retried claim is
      # answered the holding the first call wrote by the wallet itself rather
      # than a second code being taken out of the pool.
      #
      # @return [Spree::ServiceModule::Result] value is the coupon holding
      def issue(claim, right, promotion, customer, store)
        Spree::Coupons::Issue.call(
          promotion: promotion,
          source: 'membership',
          customer: customer,
          store: store,
          metadata: { 'membership_right_id' => right.id },
          idempotency_key: claim.idempotency_key
        )
      end

      def consume(claim)
        Spree::Grants.consume!(claim) unless claim.consumed?
      end
    end
  end
end
