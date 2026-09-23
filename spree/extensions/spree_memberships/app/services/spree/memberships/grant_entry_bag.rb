module Spree
  module Memberships
    # What entering a tier hands over: the points a right credits and the coupon
    # a right draws, both issued once per activation
    # (docs/plans/6.1-membership-tiers-and-rights.md).
    #
    # Neither issuer is re-implemented here — the ledger owns the lot and the
    # wallet owns the code — and both are idempotent by the key they are called
    # with. The key names the thing that caused the grant, the card and the
    # right, so a retried activation or an operator running it again hands over
    # nothing the second time.
    class GrantEntryBag
      prepend Spree::ServiceModule::Base

      # @param source [Object] what caused the bag — the card that was activated
      # @param customer [Object] who receives it
      # @param rights [Enumerable<Spree::MembershipRight>] the tier's rights
      # @return [Spree::ServiceModule::Result] value is what was handed over, as
      #   { points: Integer, coupons: Array<Spree::CouponHolding> }
      def call(source:, customer:, rights:)
        store = source.store
        bag = { points: 0, coupons: [] }

        rights.each do |right|
          points = right.entry_points
          if points.present?
            credited = credit_points(right, points, source: source, customer: customer, store: store)
            return failure(source, credited.error) if credited.failure?

            bag[:points] += points
          end

          promotion_id = right.entry_coupon
          next if promotion_id.blank?

          issued = issue_coupon(right, promotion_id, source: source, customer: customer, store: store)
          return failure(source, issued.error) if issued.failure?

          bag[:coupons] << issued.value
        end

        success(bag)
      end

      private

      def credit_points(right, points, source:, customer:, store:)
        Spree::Points::Ledger::Credit.call(
          account: Spree::PointAccount.for(store: store, customer: customer, kind: Spree::PointAccount::POINTS),
          amount: points,
          reason: REASON,
          source: source,
          idempotency_key: key(source, right, 'points')
        )
      end

      def issue_coupon(right, promotion_id, source:, customer:, store:)
        promotion = Spree::Promotion.find_by_prefix_id(promotion_id)
        return failure(source, Spree.t('memberships.errors.promotion_unknown')) if promotion.nil?

        Spree::Coupons::Issue.call(promotion: promotion, source: 'membership', customer: customer,
                                   store: store, metadata: { 'membership_card_id' => source.id },
                                   idempotency_key: key(source, right, 'coupon'))
      end

      # The card and the right are the whole key: a card is activated once, and a
      # right hands its thing over once per activation.
      def key(source, right, part)
        "membership_entry:#{source.class.name}:#{source.id}:right:#{right.id}:#{part}"
      end

      # A key the operator's reason list does not hold still moves the balance —
      # the read shows the key itself (Spree::Points::Ledger::Credit).
      REASON = 'membership_entry'.freeze
    end
  end
end
