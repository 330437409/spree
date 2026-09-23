module Spree
  module Api
    module V3
      module Store
        # One card as its holder's wallet reads it: what it grants, whether it
        # can be activated or given away yet, and the term it started when it
        # has one.
        #
        # The tier is the group's own name and the server's rank — the client
        # maps no key and derives no order — and the deadline is an instant it
        # renders verbatim.
        class MembershipCardSerializer < BaseSerializer
          typelize tier: 'Record<string, unknown> | null', status: :string, source: :string,
                   giftable: :boolean, activates_before: 'string | null',
                   activated_at: 'string | null', membership: 'Record<string, unknown> | null'

          attribute(:tier) do |card|
            tier = card.tier_setting
            next if tier.nil?

            Spree::Api::V3::Store::MembershipTierSerializer.new(tier, params: params).to_h
          end

          attributes :status, :source
          attribute(:giftable) { |card| card.giftable? }
          attribute(:activates_before) { |card| card.activates_before&.iso8601 }
          attribute(:activated_at) { |card| card.activated_at&.iso8601 }

          attribute(:membership) do |card|
            next if card.membership.nil?

            Spree::Api::V3::Store::MembershipSerializer.new(card.membership, params: params).to_h
          end
        end
      end
    end
  end
end
