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
        step :ensure_tier_is_sold
        run_hooks :validate

        ApplicationRecord.transaction do
          step :issue_term
          step :assign_tier
          step :mark_card
          step :grant_entry_bag
          run_hooks :after_activate
        end

        success(card.reload)
      end

      private

      # Entering a tier hands over what its rights carry: the points and the
      # coupons of the client's 恭喜升级 bag. Inside this transaction, because
      # both issuers write where this one does, and idempotent by the card and
      # the right, so a retried activation hands over nothing twice.
      def grant_entry_bag
        rights = Spree::MembershipRight.published.where(customer_group_id: card.customer_group_id)
        return if rights.empty?

        result = Spree::Memberships::GrantEntryBag.call(source: card, customer: entitled_customer, rights: rights)
        failure(card, result.error) if result.failure?
      end

      # A card activated twice — a retry, a double tap — is answered with the
      # card it already activated rather than refused.
      def ensure_activatable
        return if card.dormant?
        return halt!(card) if card.active? && card.activated_by_customer_id == entitled_customer.id

        failure(card, Spree.t('memberships.errors.card_not_activatable'))
      end

      # The deadline the client shows as the last day to activate or give a card
      # away. Missing it is not a refusal but a fact, and the transition that
      # writes it is the same one the sweep runs.
      def ensure_within_deadline
        return unless card.overdue?

        Spree::MembershipCards::Expire.call(card: card)
        failure(card, Spree.t('memberships.errors.card_expired'))
      end

      # A card for a tier nobody sells any more has nothing to grant, and a term
      # written for it could never hold the tier: the tier is checked before
      # anything is written rather than at the assign step, which a waiting term
      # never reaches.
      def ensure_tier_is_sold
        return if Spree::MembershipTierSetting.exists?(customer_group_id: card.customer_group_id)

        failure(card, Spree.t('memberships.errors.tier_unknown'))
      end

      # The term this card grants. The same tier's own live term is extended —
      # a running one and a waiting one alike, because the ladder's uniqueness
      # is over live terms, not over running ones; another tier's is waited out;
      # with nothing live the term starts now.
      def issue_term
        # Locked and re-read: a double tap sends two activations, and the second
        # has to find the term the first wrote rather than write another one for
        # the same customer and tier.
        card.lock!
        return @membership = card.membership if card.membership.present?

        held = Spree::Membership.live.for_customer(entitled_customer)
        same_tier = held.on(card.customer_group_id).first

        @membership = same_tier ? extend_term(same_tier) : write_term(held)
      end

      # @return [Spree::Membership]
      def extend_term(term)
        added = card.tier_setting&.term_length
        return term if added.nil?

        # From the instant the customer still holds, not from a lapsed end:
        # grace days are the tier's, and a term inside its grace window is
        # holding a tier that the customer has just paid to keep.
        from = [term.ends_at, Time.current].compact.max
        term.update!(status: 'active', ends_at: from + added)

        term
      end

      # A term that starts now, or one that waits.
      #
      # With nothing live the term starts and holds the tier; with another tier
      # already holding or waiting for the customer this one waits for that one
      # to end, and a live term with no end waits for a person rather than being
      # taken out from under.
      #
      # @return [Spree::Membership]
      def write_term(held)
        return start_now if held.empty?

        starts_at = held.where.not(ends_at: nil).order(:ends_at).last&.ends_at
        # A live term with no end is a tier held for good. A card bought under
        # one waits for a person rather than for a clock — but a term that can
        # never start is not a wait, and the card stays dormant with the
        # customer's money unspent.
        return failure(card, Spree.t('memberships.errors.tier_open_ended')) if starts_at.nil?

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
        starts_at = Time.current

        Spree::Membership.create!(
          store: card.store,
          customer: entitled_customer,
          customer_group: card.customer_group,
          status: 'active',
          starts_at: starts_at,
          ends_at: term_ends_at(starts_at)
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
          membership: membership,
          # What this card added, so voiding it takes back exactly that much
          # rather than whatever the tier's length is by then.
          metadata: card.metadata.merge('granted_days' => card.tier_setting&.validity_days)
        )
      end
    end
  end
end
