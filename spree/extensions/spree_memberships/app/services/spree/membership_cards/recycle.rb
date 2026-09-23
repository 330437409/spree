module Spree
  module MembershipCards
    # Voids a card: the client's 作废, and the one write the admin surface has.
    #
    # A dormant card simply stops being activatable. An active one takes its term
    # with it — a lost phone, a fraud report — so the entitlement ends and the
    # tier's group is left in the same transaction, which is the rule the whole
    # card/term split exists to keep
    # (docs/plans/6.1-membership-tiers-and-rights.md).
    class Recycle < Spree::Workflow
      hooks :validate, :after_recycle

      attr_reader :card

      # @param card [Spree::MembershipCard]
      # @param reason [String, nil] kept on the card, for the operator who asks
      #   where it went
      # @return [Spree::ServiceModule::Result] value is the card
      def perform(card:, reason: nil)
        super

        step :ensure_recyclable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :end_term
          step :mark_recycled
          run_hooks :after_recycle
        end

        success(card.reload)
      end

      private

      def ensure_recyclable
        return halt!(card) if card.recycled?

        failure(card, Spree.t('memberships.errors.card_not_activatable')) if card.expired?
      end

      # The entitlement goes with the card. A term that already ended, or one
      # that was never started, has nothing to give up.
      def end_term
        return if card.membership.nil? || !card.membership.live?

        Spree::Memberships::EndTerm.call(membership: card.membership, status: 'cancelled')
      end

      def mark_recycled
        card.update!(status: 'recycled', metadata: card.metadata.merge('recycled_reason' => reason).compact)
      end
    end
  end
end
