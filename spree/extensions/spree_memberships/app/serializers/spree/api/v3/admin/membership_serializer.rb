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

          include MembershipNesting

          # Which tier this term holds, named the way a card names its own: the
          # group's name and the ladder's rung.
          attribute(:tier) { |membership| nested_tier(membership) }

          attributes :metadata, :created_at, :updated_at
        end
      end
    end
  end
end
