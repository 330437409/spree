module Spree
  module Api
    module V3
      module Store
        module ScenarioOrders
          # What a settled purchase released: the card it issued, read back off
          # the purchase rather than searched for in the wallet.
          #
          # The purchase is the frame's row and the card is this gem's, so the
          # frame's own serializer carries neither the card nor its tier — this
          # is the read that connects the two, addressed by the purchase because
          # that is what the client is holding once it has paid
          # (docs/plans/6.1-membership-tiers-and-rights.md).
          class MembershipCardsController < Store::BaseController
            prepend_before_action :require_authentication!

            # GET /api/v3/store/scenario_orders/:scenario_order_id/membership_card
            def show
              purchase = Spree::ScenarioOrder.for_store(current_store).for_customer(current_user).
                         find_by_prefix_id!(params[:scenario_order_id])
              # The purchase's own customer is what makes this the caller's card,
              # so the card is not asked again whose it is: a kind that issues it
              # to somebody other than the buyer would otherwise have the buyer
              # answered nothing for the purchase they paid for.
              #
              # What the serializer reads is loaded with the row, as the wallet
              # loads it: a post-payment read should not pay a query per tier.
              card = Spree::MembershipCard.for_store(current_store).
                     includes(:pending_transfer, tier_setting: :customer_group).
                     find_by!(scenario_order: purchase)

              render json: serialize_resource(card)
            end

            protected

            def serializer_class
              Spree::Api::V3::MembershipCardSerializer
            end
          end
        end
      end
    end
  end
end
