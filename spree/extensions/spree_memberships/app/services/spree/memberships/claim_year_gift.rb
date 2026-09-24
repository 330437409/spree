module Spree
  module Memberships
    # 立即领取 — the annual gift, claimed.
    #
    # A claim draws one coupon of the gift, hands it over through the wallet and
    # records the claim as a `Spree::Grant` of {Spree::Memberships::YearGiftClaim},
    # all of it in one transaction: a claim whose coupon could not be issued is
    # not a claim, so the member keeps the allowance and may ask again.
    #
    # The two rows share one idempotency key — the member, the tier, the store's
    # own year and the coupon — so a retried request is answered the coupon the
    # first call issued rather than a second one out of the pool, and the year's
    # allowance is only spent by a claim that is not this one already
    # (docs/plans/6.1-membership-tiers-and-rights.md).
    class ClaimYearGift
      prepend Spree::ServiceModule::Base

      # What the wallet's refusals mean, in a caller's own words. It refuses in
      # its own vocabulary, and a client is told what the refusal means rather
      # than which token spelled it.
      REFUSAL_MESSAGES = {
        'coupon_none_left' => 'memberships.errors.gift_coupon_none_left',
        'coupon_already_recorded' => 'memberships.errors.gift_coupon_taken_back',
        'already_recorded' => 'memberships.errors.gift_coupon_taken_back',
        'coupon_just_taken' => 'memberships.errors.gift_coupon_contended'
      }.freeze

      # @param right [Spree::MembershipRight] the tier's own gift
      # @param customer [Object] the member claiming it
      # @param promotion_id [String, nil] which of the gift's coupons, by its
      #   prefixed id; the first one they have not taken when omitted
      # @param store [Spree::Store, nil]
      # @return [Spree::ServiceModule::Result] value is the coupon holding
      def call(right:, customer:, promotion_id: nil, store: nil)
        store ||= Spree::Current.store

        return failure(right, Spree.t('memberships.errors.gift_not_a_gift')) unless right.is_a?(Spree::MembershipRights::GiveGift)
        return failure(right, Spree.t('memberships.errors.gift_not_coupons')) unless right.coupon_gift?

        centre = Spree::Memberships::MemberCentre.new(store: store, customer: customer)
        # A claim belongs to a tier, so it is the member's own tier that may
        # claim it: the gift of a tier somebody is not on is not theirs to take.
        return failure(right, Spree.t('memberships.errors.gift_not_the_tiers')) unless centre.holds?(right)

        gift = centre.payload_for(right)
        coupon = promotion_id.present? ? gift.coupon_for(promotion_id) : gift.next_coupon

        return failure(right, Spree.t('memberships.errors.gift_coupon_unknown')) if coupon.nil? && promotion_id.present?
        return failure(right, empty_or_claimed(gift)) if coupon.nil?

        # A replay is answered the coupon it already issued, so the allowance is
        # only spent by a claim the member has not made yet.
        return failure(right, Spree.t('memberships.errors.gift_allowance_spent')) if !coupon.claimed? && gift.can_count.zero?

        record(right: right, customer: customer, store: store, gift: gift, coupon: coupon)
      end

      private

      # A gift with no coupons configured is not one everything has been taken
      # from, and the two read the same to a client that is only told "claimed".
      #
      # @return [String]
      def empty_or_claimed(gift)
        Spree.t(gift.coupons.empty? ? 'memberships.errors.gift_empty' : 'memberships.errors.gift_claimed')
      end

      # @return [Spree::ServiceModule::Result] value is the coupon holding
      def record(right:, customer:, store:, gift:, coupon:)
        tier = right.customer_group
        context = { customer: customer, tier: tier, promotion: coupon.promotion, year: gift.year }
        key = YearGiftClaim.idempotency_key_for(context)
        result = nil

        Spree::Grant.transaction(requires_new: true) do
          # The tier's own row is what the allowance is spent under: two claims
          # arriving together serialise here, so this one's own row is in the
          # count the other stands down from.
          tier.lock!

          # The claim is the allowance, so it is written before the coupon is
          # drawn — and a coupon the pool refuses then takes the claim with it.
          claim = Spree::Grants.grant!(
            kind: YearGiftClaim,
            customer: customer,
            source: tier,
            store: store,
            idempotency_key: key,
            context: context,
            metadata: { 'promotion_id' => coupon.promotion.id.to_s, 'membership_right_id' => right.id }
          )
          if claim.failure?
            result = failure(right, refusal_message(claim.error))
            raise ActiveRecord::Rollback
          end

          # Asked again with this claim in hand, and only for a claim that is not
          # a replay of one already made: a claim that raced another past the
          # reading above finds the year spent and stands down.
          if !coupon.claimed? && spent?(right, customer, store)
            result = failure(right, Spree.t('memberships.errors.gift_allowance_spent'))
            raise ActiveRecord::Rollback
          end

          issued = issue(key: key, right: right, customer: customer, store: store, promotion: coupon.promotion)
          if issued.failure?
            result = failure(right, refusal_message(issued.error))
            raise ActiveRecord::Rollback
          end

          # What the claim released, written without another event: the row
          # already exists, and this only fills in what it points at.
          if claim.value.issued_id.blank?
            claim.value.update_columns(issued_type: issued.value.class.name, issued_id: issued.value.id)
          end

          # A claim is paid the moment it is written, so it is consumed here
          # rather than left standing as a debt — a replay finds it consumed,
          # which the primitive's own refusal answers.
          Spree::Grants.consume!(claim.value)
          result = success(issued.value)
        end

        result
      end

      # Whether the year now holds more claims than its allowance, this claim
      # included — asked of the year's own reader, read under the tier's own
      # lock, where every claim that raced this one has either committed or is
      # waiting for the lock.
      #
      # @return [Boolean]
      def spent?(right, customer, store)
        Spree::Memberships::YearGift.new(right: right, customer: customer, store: store).over_allowance?
      end

      # A refusal a client can act on. A validation error keeps its own message,
      # a refusal this gem knows is translated, and anything else is answered as
      # a coupon that could not be handed over rather than swallowed.
      #
      # @param error [Object] the wallet's or the primitive's refusal
      # @return [String]
      def refusal_message(error)
        return error if error.is_a?(String)

        code = error.respond_to?(:value) ? error.value : error
        return code.full_messages.to_sentence if code.respond_to?(:full_messages)

        key = REFUSAL_MESSAGES[code.to_s]
        key ? Spree.t(key) : Spree.t('memberships.errors.gift_coupon_unavailable')
      end

      # The wallet issues under the claim's own key, so a retried claim is
      # answered the holding the first call wrote by the wallet itself rather
      # than a second code being taken out of the pool.
      #
      # @return [Spree::ServiceModule::Result] value is the coupon holding
      def issue(key:, right:, customer:, store:, promotion:)
        Spree::Coupons::Issue.call(
          promotion: promotion,
          source: 'membership',
          customer: customer,
          store: store,
          metadata: { 'membership_right_id' => right.id },
          idempotency_key: key
        )
      end
    end
  end
end
