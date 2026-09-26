module Spree
  module Api
    module V3
      module Admin
        # One rung of the ladder as the operator edits it: the store's own shape
        # of it, plus the group the tier *is* and the threshold in the money an
        # operator reads.
        #
        # The group's id is what the settings and the rights are addressed by —
        # a tier is a group carrying settings, so the operator's writes hang off
        # the group while the ladder is read as a ladder.
        #
        # `display_threshold` is declared here rather than on the store's own
        # shape: the operator's screen is what reads it, and a customer-facing
        # payload carries no figure nobody reads.
        class MembershipTierSerializer < V3::MembershipTierSerializer
          typelize customer_group_id: 'string | null', display_threshold: 'string | null'

          attribute(:customer_group_id) { |tier| tier.customer_group&.prefixed_id }
          attribute(:display_threshold) { |tier| tier.display_threshold&.to_s }
        end
      end
    end
  end
end
