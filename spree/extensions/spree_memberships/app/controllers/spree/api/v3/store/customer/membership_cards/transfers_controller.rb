module Spree
  module Api
    module V3
      module Store
        module Customer
          module MembershipCards
            # 相赠 and 作废: the window a card is inside, and the only two things a
            # customer does with one.
            #
            # The window itself belongs to the shared primitive — a transfer is a
            # row of `Spree::Transfer` — so this controller is a thin door onto
            # `Spree::Transfers`, and the card's own rules are its contract
            # (docs/plans/6.1-transfer-primitive.md).
            class TransfersController < ResourceController
              prepend_before_action :require_authentication!
              before_action :set_card

              # GET /api/v3/store/customers/me/membership_cards/:membership_card_id/transfers
              def index
                windows = Spree::Transfer.for_giver(current_user).where(transferable: @card)

                render json: { data: windows.map { |window| serialize_resource(window) } }
              end

              # POST /api/v3/store/customers/me/membership_cards/:membership_card_id/transfers
              def create
                result = Spree::Transfers.give!(
                  from: current_user,
                  transferable: @card,
                  to_phone: permitted_params[:to_phone],
                  message: permitted_params[:message],
                  expires_at: permitted_params[:expires_at]
                )
                return render_result_error(result) if result.failure?

                render json: serialize_resource(result.value), status: :created
              end

              # DELETE /api/v3/store/customers/me/membership_cards/:membership_card_id/transfers/:id
              #
              # 作废 is a cancellation rather than a deletion: the row stays as the
              # record of a gift that was taken back.
              def destroy
                window = Spree::Transfer.for_giver(current_user).where(transferable: @card).
                         find_by_prefix_id!(params[:id])
                result = Spree::Transfers.cancel!(window)
                return render_result_error(result) if result.failure?

                render json: serialize_resource(result.value)
              end

              protected

              def model_class
                Spree::Transfer
              end

              def serializer_class
                Spree::Api::V3::Store::MembershipCardTransferSerializer
              end

              def permitted_params
                params.permit(:to_phone, :message, :expires_at)
              end

              # Through the customer's own wallet: a card that is not theirs is
              # not found.
              def set_card
                @card = Spree::MembershipCard.for_store(current_store).
                        for_customer(current_user).
                        find_by_prefix_id!(params[:membership_card_id])
              end
            end
          end
        end
      end
    end
  end
end
