module Spree
  module Api
    module V3
      # One card as its holder's wallet reads it: what it grants, whether it
      # can be activated or given away yet, and the term it started when it
      # has one.
      #
      # The tier is the group's own name and the server's rank — the client
      # maps no key and derives no order — and the deadline is an instant it
      # renders verbatim.
      class MembershipCardSerializer < BaseSerializer
        typelize tier: 'Record<string, unknown> | null', status: :string, source: :string,
                 entry_bag: 'Record<string, unknown> | null',
                 giftable: :boolean, activates_before: 'string | null',
                 activated_at: 'string | null', membership: 'Record<string, unknown> | null',
                 transfer: 'Record<string, unknown> | null'

        attribute(:tier) do |card|
          tier = card.tier_setting
          next if tier.nil?

          Spree::Api::V3::MembershipCardTierSerializer.new(tier, params: params).to_h
        end

        attributes :status, :source

        # What this card's activation handed over — the client's 恭喜升级 bag.
        # Only ever populated by that activation, which is why the wallet's cards
        # answer nil: what a tier carries today is not what a member was given.
        attribute(:entry_bag) do |card|
          bag = card.entry_bag
          next if bag.blank?

          { 'points' => bag[:points].to_i, 'coupons' => bag[:coupons].to_a.size }
        end
        attribute(:giftable) { |card| card.giftable? }
        attribute(:activates_before) { |card| card.activates_before&.iso8601 }
        attribute(:activated_at) { |card| card.activated_at&.iso8601 }

        attribute(:membership) do |card|
          next if card.membership.nil?

          Spree::Api::V3::MembershipSerializer.new(card.membership, params: params).to_h
        end

        # The window the card is inside: what the client reads as 赠送中, and
        # what carries the token it shares.
        attribute(:transfer) do |card|
          window = card.pending_transfer
          next if window.nil?

          Spree::Api::V3::MembershipCardTransferSerializer.new(window, params: params).to_h
        end
      end
    end
  end
end
