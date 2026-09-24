module Spree
  module Api
    module V3
      # A window read by somebody deciding whether to redeem it: the card, the
      # window, and **what the card is worth**.
      #
      # Its own serializer rather than a field on the window, because the wallet
      # and the giver render the same window and neither shows rights — a
      # preloaded tier answers this list, and a wallet of cards must not pay for
      # it per row.
      class MembershipCardVoucherSerializer < BaseSerializer
        typelize token: :string, status: :string, message: 'string | null', expires_at: 'string | null',
                 valid_from: 'string | null', rights: 'MembershipRight[]',
                 card: 'MembershipCardSummary | null'

        attributes :token
        attribute(:status) { |transfer| transfer.display_status }
        attributes :message
        attribute(:expires_at) { |transfer| transfer.expires_at&.iso8601 }
        attribute(:valid_from) { |transfer| transfer.created_at&.iso8601 }

        # What the card grants, so the recipient reads what they are about to
        # claim rather than claiming to find out — and *only* what claiming
        # grants, which is the tier's published rights, the same list the
        # activation pays out. An unpublished right is authored but not yet
        # given, and promising it here would be a promise the claim breaks.
        #
        # Empty for a card whose tier is gone, which is what claiming it would
        # find too.
        attribute(:rights) do |transfer|
          card = transfer.transferable
          next [] unless card.is_a?(Spree::MembershipCard)

          card.tier_setting&.published_rights.to_a.map do |right|
            Spree::Api::V3::MembershipRightSerializer.new(right, params: params).to_h
          end
        end

        attribute(:card) do |transfer|
          card = transfer.transferable
          next unless card.is_a?(Spree::MembershipCard)

          Spree::Api::V3::MembershipCardSummarySerializer.new(card, params: params).to_h
        end
      end
    end
  end
end
