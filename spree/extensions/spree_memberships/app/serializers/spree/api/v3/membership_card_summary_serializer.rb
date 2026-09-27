module Spree
  module Api
    module V3
      # A card as somebody who does not hold it yet reads it: what the gift
      # grants, whether it can still be activated, and the term it started when
      # the claim was the activation.
      #
      # Lean on purpose. The wallet's card read carries the window the card is
      # inside, and a window carries the card — so rendering one through the
      # other is a loop, and the recipient wants the card, not the token they
      # already hold. The term is different: it is what claiming just produced,
      # and the claimer reads it here rather than asking again.
      class MembershipCardSummarySerializer < BaseSerializer
        typelize tier: 'Record<string, unknown> | null', status: :string,
                 activates_before: 'string | null', membership: 'Record<string, unknown> | null'

        include MembershipNesting

        attribute(:tier) { |card| nested_tier(card) }

        attributes :status
        attribute(:activates_before) { |card| card.activates_before&.iso8601 }
        attribute(:membership) { |card| nested_membership(card) }
      end
    end
  end
end
