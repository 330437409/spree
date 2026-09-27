module Spree
  module Api
    module V3
      # The records a membership payload nests: the tier it grants or holds, and
      # the term a card started.
      #
      # A card and a term both reach their tier through the same settings row and
      # both publish it the same way — the group's name and the ladder's rung —
      # so the projection lives here rather than once per payload.
      module MembershipNesting
        # @param record [Object] anything answering `tier_setting`
        # @return [Hash, nil]
        def nested_tier(record)
          tier = record.tier_setting
          return if tier.nil?

          Spree::Api::V3::MembershipCardTierSerializer.new(tier).to_h
        end

        # @param card [Spree::MembershipCard]
        # @return [Hash, nil]
        def nested_membership(card)
          membership = card.membership
          return if membership.nil?

          Spree::Api::V3::MembershipSerializer.new(membership).to_h
        end
      end
    end
  end
end
