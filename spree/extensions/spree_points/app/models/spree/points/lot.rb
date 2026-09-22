module Spree
  module Points
    # The kind of grant a lot is, registered in `Spree.grant_kinds`.
    #
    # One kind for both balances: which balance a lot feeds is its account's
    # kind, not a difference in what the grant is. Growth value never expires
    # and is never spent, and both facts are checked where they apply — the
    # account carries no date, and a spend that reaches a growth-value lot is
    # refused by the service that spends.
    class Lot < Spree::Grants::Kind
      def self.api_type
        'point_lot'
      end

      # This kind builds no key of its own. Every producer of a lot knows the
      # one thing that makes it unique — the order it was earned on, the
      # review, the adjustment an operator made — and passes it, so a retry
      # records nothing and answers the lot the first call wrote.
      #
      # @raise [NotImplementedError]
      def self.idempotency_key_for(_context)
        raise NotImplementedError, 'a point lot is granted with an explicit idempotency_key'
      end

      # A lot is consumed in part, in an amount the spend names — which the
      # primitive's `consume!(grant)` has no way to say. The spend writes a
      # ledger entry and its allocations through {Spree::Points::Ledger}, so a
      # caller arriving here is asking the wrong door.
      #
      # @return [Spree::ServiceModule::Result]
      def self.consume!(grant)
        refuse(grant, :spend_through_the_ledger)
      end
    end
  end
end
