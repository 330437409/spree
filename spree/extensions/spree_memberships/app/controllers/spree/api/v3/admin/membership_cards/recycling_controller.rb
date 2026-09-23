module Spree
  module Api
    module V3
      module Admin
        module MembershipCards
          # The one write the cards surface has.
          #
          # A card the client cannot void — because the phone is gone, or
          # because the purchase was fraudulent — is voided here, and the work
          # is the same transition the client's own 作废 runs.
          class RecyclingController < ResourceController
            scoped_resource :memberships

            # POST /api/v3/admin/membership_cards/:membership_card_id/recycling
            def create
              @card = Spree::MembershipCard.for_store(current_store).
                      find_by_prefix_id!(params[:membership_card_id])
              authorize_resource!(@card, :update)

              result = Spree::MembershipCards::Recycle.call(card: @card, reason: permitted_params[:reason])
              return render_result_error(result) if result.failure?

              render json: serialize_resource(result.value)
            end

            protected

            def model_class
              Spree::MembershipCard
            end

            def serializer_class
              Spree::Api::V3::Admin::MembershipCardSerializer
            end

            def permitted_params
              params.permit(:reason)
            end
          end
        end
      end
    end
  end
end
