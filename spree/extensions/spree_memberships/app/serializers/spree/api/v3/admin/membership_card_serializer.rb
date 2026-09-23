module Spree
  module Api
    module V3
      module Admin
        # A card as the back office reads it: whose it is, where it came from,
        # what it started and when — everything a support desk needs to answer
        # "where did this card go".
        class MembershipCardSerializer < V3::MembershipCardSerializer
          typelize customer_id: :string, customer_email: 'string | null',
                   membership_id: 'string | null', scenario_order_id: 'string | null',
                   activated_by_customer_id: 'string | null',
                   metadata: 'Record<string, unknown> | null'

          attribute(:customer_id) { |card| card.customer&.prefixed_id }
          attribute(:customer_email) { |card| card.customer&.email }
          attribute(:membership_id) { |card| card.membership&.prefixed_id }
          attribute(:scenario_order_id) { |card| card.scenario_order&.prefixed_id }
          attribute(:activated_by_customer_id) { |card| card.activated_by_customer&.prefixed_id }

          attributes :metadata, :created_at, :updated_at
        end
      end
    end
  end
end
