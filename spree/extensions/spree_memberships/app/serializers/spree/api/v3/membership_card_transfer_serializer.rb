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
        typelize token: :string, status: :string, message: 'string | null', expires_at: 'string | null',
                 valid_from: 'string | null', rights: 'Array<Record<string, unknown>>',
                 card: 'MembershipCardSummary | null'

        attributes :token
        attribute(:status) { |transfer| transfer.display_status }
        attributes :message
        attribute(:expires_at) { |transfer| transfer.expires_at&.iso8601 }
        # A window is live from the moment it is opened, so that is what a reader
        # counting towards the end needs: it is always behind them.
        attribute(:valid_from) { |transfer| transfer.created_at&.iso8601 }

        # What the card is worth, so the recipient reads what they are about to
        # claim rather than claiming to find out. Empty for a transferable that
        # is not this gem's.
        attribute(:rights) do |transfer|
          card = transfer.transferable
          next [] unless card.is_a?(Spree::MembershipCard)

          card.tier_rights.map do |right|
            Spree::Api::V3::MembershipRightSerializer.new(right, params: params).to_h
          end
        end

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
