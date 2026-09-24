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
              card = Spree::MembershipCard.for_store(current_store).for_customer(current_user).
                     find_by!(scenario_order: purchase)

              render json: Spree::Api::V3::MembershipCardSerializer.new(
                card, params: serializer_params
              ).to_h
            end
          end
        end
      end
    end
  end
end
