module Spree
  module Memberships
    # Ends a term, and takes the tier's group with it.
    #
    # One writer for the pair, because member pricing reads the group: a term
    # that has ended while the customer is still in the group is a lapsed member
    # who keeps the price (docs/plans/6.1-membership-tiers-and-rights.md).
    #
    # A superseded term is not ended here — the customer's next one starts and
    # moves the group in that same step, which is where an upgrade lands.
    class EndTerm < Spree::Workflow
      hooks :validate, :after_end

      attr_reader :membership

      # @param membership [Spree::Membership]
      # @param status [String] `expired` when its window ran out, `cancelled`
      #   when somebody ended it early — a voided card, a fraudulent purchase
      # @return [Spree::ServiceModule::Result] value is the membership
      def perform(membership:, status: 'expired')
        super

        step :ensure_open
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_ended
          step :leave_tier
          run_hooks :after_end
        end

        success(membership.reload)
      end

      private

      # Ending a term that already ended is a retry, not a mistake: the sweep
      # runs again on its next pass and must not refuse its own work.
      def ensure_open
        halt!(membership) if membership.expired? || membership.cancelled?
      end

      def mark_ended
        attributes = { status: status }
        # A cancellation cuts the window short; an expiry already went by.
        attributes[:ends_at] = Time.current if status == 'cancelled'

        failure(membership) unless membership.update(attributes)
      end

      # The customer leaves the ladder — unless another tier is holding them
      # right now, which is the case an upgrade leaves behind: the old term ends
      # after the new one has already started, and leaving every tier would take
      # the new one away.
      def leave_tier
        return if membership.customer.nil?
        return if Spree::Membership.running.for_customer(membership.customer).exists?

        Spree::Memberships::UnassignTier.call(customer: membership.customer)
      end
    end
  end
end
