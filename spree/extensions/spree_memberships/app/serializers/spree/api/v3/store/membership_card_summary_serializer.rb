module Spree
  module Api
    module V3
      module Store
        # A card as somebody who does not hold it yet reads it: what the gift
        # grants, and whether it can still be activated.
        #
        # Lean on purpose. The wallet's card read carries the window the card is
        # inside, and a window carries the card — so rendering one through the
        # other is a loop, and the recipient wants the card, not the token they
        # already hold.
        class MembershipCardSummarySerializer < BaseSerializer
          typelize tier: 'Record<string, unknown> | null', status: :string,
                   activates_before: 'string | null'

          attribute(:tier) do |card|
            tier = card.tier_setting
            next if tier.nil?

            Spree::Api::V3::Store::MembershipCardTierSerializer.new(tier, params: params).to_h
          end

          attributes :status
          attribute(:activates_before) { |card| card.activates_before&.iso8601 }
        end
      end
    end
  end
end
