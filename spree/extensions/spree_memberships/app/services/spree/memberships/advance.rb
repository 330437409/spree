module Spree
  module Memberships
    # Moves one term along: starts the ones whose window opened, extends the
    # ones the tier renews by itself, warns the ones inside their grace window,
    # and ends the ones that ran out.
    #
    # The sweep's decision in one place, so the job stays a query and the rules
    # read on their own. Ported from spree_crm's `ExpireLapsedJob` rather than
    # re-invented (ruled 2026-09-18), with one addition: a term that ends is what
    # lets the customer's next one start, which is how an upgrade lands.
    class Advance < Spree::Workflow
      attr_reader :membership

      # @param membership [Spree::Membership]
      # @param now [Time] the instant the sweep is asking about
      # @return [Spree::ServiceModule::Result] value is the membership
      def perform(membership:, now: Time.current)
        super

        ApplicationRecord.transaction do
          step :advance
        end

        success(membership.reload)
      end

      private

      def advance
        return start_pending if due_to_start?
        return extend_term if renews_itself?
        # The sweep reaches every term whose start or end has moved, and only
        # some of them are over: one whose window is still open has nothing to
        # answer.
        return membership unless closed?
        return enter_grace if within_grace?

        result = Spree::Memberships::EndTerm.call(membership: membership, status: 'expired')
        failure(membership, result.error) if result.failure?

        membership
      end

      # The window opened: from here the customer holds this term, and the tier's
      # group moves with it in the same step.
      def start_pending
        # A term can outlive its customer — Spree adds no foreign keys — and
        # there is nobody for it to hold a tier for. Left as it is rather than
        # raising, so one orphan does not stop the sweep for every term behind
        # it.
        return membership if membership.customer.nil?

        membership.update!(status: 'active')
        result = Spree::Memberships::AssignTier.call(customer: membership.customer,
                                                     customer_group: membership.customer_group)
        failure(membership, result.error) if result.failure?

        membership
      end

      # Renewed by the tier's own setting rather than billed — the platform
      # grants the extension, and the window moves forward from where it ended
      # rather than restarting.
      def extend_term
        length = tier&.term_length
        # From the instant the customer still holds, not from a lapsed end: the
        # grace window is the tier's, and a renewal measured from behind it
        # would spend the days the customer just paid for.
        from = [membership.ends_at, now].compact.max
        membership.update!(status: 'active', starts_at: from, ends_at: length ? from + length : nil)

        membership
      end

      # Inside the tier's grace window: the term is lapsed, and the customer
      # keeps the group until the window closes.
      def enter_grace
        membership.update!(status: 'past_due')

        membership
      end

      def due_to_start?
        membership.pending? && membership.starts_at.present? && membership.starts_at <= now
      end

      def renews_itself?
        return false unless membership.active? && closed? && tier&.auto_renew?
        # A term already waiting for this instant is what replaces this one:
        # renewing beside a successor leaves a phantom tier that keeps renewing
        # for a customer who has moved on.
        return false if waiting_successor?

        true
      end

      # @return [Boolean] whether another term is waiting to take this one's place
      def waiting_successor?
        Spree::Membership.with_status(:pending).for_customer(membership.customer).
          where.not(id: membership.id).exists?
      end

      def within_grace?
        grace = tier&.grace_period
        return false if grace.nil? || membership.ends_at.nil?

        now <= membership.ends_at + grace
      end

      def closed?
        membership.ends_at.present? && membership.ends_at <= now
      end

      # @return [Spree::MembershipTierSetting, nil]
      def tier
        @tier ||= membership.tier_setting
      end
    end
  end
end
