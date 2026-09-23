module Spree
  module Api
    module V3
      # A gift on its way: the token that carries it, who may act on it, and the
      # card it holds.
      #
      # No customer is named, either side. The recipient reads this before
      # signing in — that is the point of a token-addressed read — so the giver
      # is not theirs to learn, and the claimer is not known until they claim.
      class MembershipCardTransferSerializer < BaseSerializer
        typelize status: :string, message: 'string | null', expires_at: 'string | null',
                 card: 'Record<string, unknown> | null'

        attributes :token
        attribute(:status) { |transfer| transfer.display_status }
        attributes :message
        attribute(:expires_at) { |transfer| transfer.expires_at&.iso8601 }

        # The lean read: a window carries the card, and the wallet's card
        # carries its window, so rendering one through the other is a loop.
        attribute(:card) do |transfer|
          card = transfer.transferable
          next unless card.is_a?(Spree::MembershipCard)

          Spree::Api::V3::MembershipCardSummarySerializer.new(card, params: params).to_h
        end
      end
  end
end
end
