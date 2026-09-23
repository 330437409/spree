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
          step :release_term
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

      # The entitlement goes with the card — its own share of it.
      #
      # Two cards of one tier share a single term by design: the second extends
      # the first's. So a term another card still points at is *shortened* by
      # what this card added, and only a term nobody else holds is ended, group
      # and all. Ending a shared one would take away what the other card paid
      # for, and an active card cannot be activated again to get it back.
      def release_term
        membership = card.membership
        return if membership.nil?

        return shorten(membership) if shared?(membership)

        result = Spree::Memberships::EndTerm.call(membership: membership, status: 'cancelled')
        failure(card, result.error) if result.failure?
      end

      # @return [Boolean] whether another card still points at this term
      def shared?(membership)
        Spree::MembershipCard.where(membership_id: membership.id).where.not(id: card.id).exists?
      end

      # What this card added, taken back: the card's own record of what it
      # granted, so a tier whose length changed since still comes back exactly.
      # Never below now — the customer keeps the window they have run through.
      def shorten(membership)
        added = card.metadata['granted_days'].to_i.days
        return if added.zero? || membership.ends_at.nil?

        ends_at = [membership.ends_at - added, Time.current].max
        membership.update!(ends_at: ends_at) if ends_at < membership.ends_at
      end

      def mark_recycled
        card.update!(status: 'recycled', metadata: card.metadata.merge('recycled_reason' => reason).compact)
      end
    end
  end
end
