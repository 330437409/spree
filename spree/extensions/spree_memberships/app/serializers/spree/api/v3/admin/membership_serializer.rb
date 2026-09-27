module Spree
  module Api
    module V3
      module Admin
        # A term as the back office reads it: who holds which tier, and until
        # when.
        class MembershipSerializer < V3::MembershipSerializer
          typelize customer_id: :string, customer_email: 'string | null',
                   customer_group_id: :string, tier: 'Record<string, unknown> | null',
                   metadata: 'Record<string, unknown> | null'

          attribute(:customer_id) { |membership| membership.customer&.prefixed_id }
          attribute(:customer_email) { |membership| membership.customer&.email }
          attribute(:customer_group_id) { |membership| membership.customer_group&.prefixed_id }

          # Which tier this term holds, named the way a card names its own: the
          # group's name and the ladder's rung. A term reaches its tier through
          # the same settings row, so the operator's list reads the tier rather
          # than resolving a group id of its own.
          attribute(:tier) do |membership|
            tier = membership.tier_setting
            next if tier.nil?

            Spree::Api::V3::MembershipCardTierSerializer.new(tier, params: params).to_h
          end

          attributes :metadata, :created_at, :updated_at
        end
      end
    end
  end
end
