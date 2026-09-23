module Spree
  module MembershipCards
    # Turns a dormant card into a term, for whoever activates it.
    #
    # Activation and claiming are one transition from two doors — the client
    # sends one call for both and says which with `activateType` — and the work
    # is identical either way: the card leaves `dormant` and a term starts for
    # the customer the caller names, which is the buyer for 自己激活 and the
    # claimer for a gift (docs/plans/6.1-membership-tiers-and-rights.md).
    #
    # **A term and the tier's group move together.** A term that runs now puts
    # the customer on the tier in the same transaction; a customer who already
    # holds a running term keeps it, and the new one waits for the tier it
    # replaces. That is the client's own overlap warning — 自{lowEndTime}起，您的
    # 权益将变更为… — and it is what keeps one group per customer true.
    class Activate < Spree::Workflow
      hooks :validate, :after_activate

      attr_reader :card, :membership

      # Who is entitled to the term this card starts: the buyer, or whoever
      # claimed it.
      attr_reader :entitled_customer

      # @param card [Spree::MembershipCard] the dormant card
      # @param customer [Object, nil] who is entitled; the buyer when omitted
      # @return [Spree::ServiceModule::Result] value is the card
      def perform(card:, customer: nil)
        super
        @entitled_customer = customer || card.customer

        step :ensure_activatable
        step :ensure_within_deadline
        run_hooks :validate

        ApplicationRecord.transaction do
          step :issue_term
          step :assign_tier
          step :mark_card
          run_hooks :after_activate
        end

        success(card.reload)
      end

      private

      # A card activated twice — a retry, a double tap — is answered with the
      # card it already activated rather than refused.
      def ensure_activatable
        return if card.dormant?
        return halt!(card) if card.active? && card.activated_by_customer_id == entitled_customer.id

        failure(card, Spree.t('memberships.errors.card_not_activatable'))
      end

      # The deadline the client shows as the last day to activate or give a card
      # away. Missing it is not a refusal but a fact: the card is expired.
      def ensure_within_deadline
        return unless card.overdue?

        card.update!(status: 'expired')
        failure(card, Spree.t('memberships.errors.card_expired'))
      end

      # The term this card grants. The same tier's own running term is extended
      # by this card's length; another tier's is waited out; with nothing
      # running the term starts now.
      def issue_term
        running = Spree::Membership.running.for_customer(entitled_customer)
        same_tier = running.on(card.customer_group_id).first

        @membership = same_tier ? extend_term(same_tier) : write_term(running)
      end

      # @return [Spree::Membership]
      def extend_term(term)
        added = card.tier_setting&.term_length
        term.update!(ends_at: term.ends_at + added) if added && term.ends_at
        term
      end

      # A card that starts now, or the one that waits.
      #
      # With nothing running the term starts and holds the tier; with another
      # tier still running it waits for that one to end, and a running term with
      # no end waits for a person rather than being taken out from under.
      #
      # @return [Spree::Membership]
      def write_term(running)
        return start_now if running.empty?

        starts_at = running.where.not(ends_at: nil).order(:ends_at).last&.ends_at

        Spree::Membership.create!(
          store: card.store,
          customer: entitled_customer,
          customer_group: card.customer_group,
          status: 'pending',
          starts_at: starts_at,
          ends_at: term_ends_at(starts_at)
        )
      end

      # @return [Spree::Membership]
      def start_now
        Spree::Membership.create!(
          store: card.store,
          customer: entitled_customer,
          customer_group: card.customer_group,
          status: 'active',
          starts_at: Time.current,
          ends_at: term_ends_at(Time.current)
        )
      end

      # @return [ActiveSupport::TimeWithZone, nil] nil when the tier sets no
      #   length, which is a term nobody has to renew
      def term_ends_at(starts_at)
        length = card.tier_setting&.term_length
        starts_at + length if starts_at && length
      end

      # Starting now is what puts the customer on the tier. A waiting term does
      # not, and neither does a pending one — the group is what member pricing
      # reads, so the two move together or not at all.
      def assign_tier
        return unless membership.running?

        result = Spree::Memberships::AssignTier.call(customer: entitled_customer,
                                                     customer_group: card.customer_group)
        failure(card, result.error) if result.failure?
      end

      def mark_card
        card.update!(
          status: 'active',
          activated_at: Time.current,
          activated_by_customer: entitled_customer,
          membership: membership
        )
      end
    end
  end
end
