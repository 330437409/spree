module Spree
  module MembershipCards
    # A dormant card whose deadline to activate or give away has passed.
    #
    # Nothing is taken from anybody: a card was never an entitlement, and the
    # state is a fact about it — the client renders 已失效 for this and for a
    # recycled card alike.
    class Expire < Spree::Workflow
      hooks :validate, :after_expire

      attr_reader :card

      # @param card [Spree::MembershipCard]
      # @return [Spree::ServiceModule::Result] value is the card
      def perform(card:)
        super

        step :ensure_overdue
        run_hooks :validate

        step :mark_expired
        run_hooks :after_expire

        success(card.reload)
      end

      private

      # The sweep runs again on its next pass, and a card it already expired is
      # its own work rather than a mistake.
      def ensure_overdue
        halt!(card) unless card.overdue?
      end

      def mark_expired
        failure(card) unless card.update(status: 'expired')
      end
    end
  end
end
