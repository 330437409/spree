module Spree
  module Api
    module V3
      # The tier a card grants, as the wallet shows it: its name and its rung.
      #
      # Deliberately not the member centre's tier read: that one counts the
      # rights the tier carries, which is a query per tier, and a wallet of
      # five cards would pay for it five times over to render a badge.
      class MembershipCardTierSerializer < BaseSerializer
        typelize name: :string, rank: :number

        attribute(:name) { |tier| tier.name }
        attribute(:rank) { |tier| tier.rank }
      end
    end
  end
end
