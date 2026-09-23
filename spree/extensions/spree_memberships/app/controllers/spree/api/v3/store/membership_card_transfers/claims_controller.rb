module Spree
  module Api
    module V3
      module Store
        module MembershipCardTransfers
          # 领取 — the claim, which is the activation.
          #
          # The recipient is signed in by now, so this is theirs to send; the card
          # leaves `dormant` for them and the term starts in the same transaction,
          # through the transfer contract.
          class ClaimsController < ResourceController
            prepend_before_action :require_authentication!

            # POST /api/v3/store/membership_card_transfers/:membership_card_transfer_token/claims
            def create
              # Found whatever its state, so a lapsed window is answered as one
              # rather than as a token that means nothing.
              window = Spree::Transfer.find_by(token: params[:membership_card_transfer_token])
              raise ActiveRecord::RecordNotFound if window.nil?

              result = Spree::Transfers.accept!(window, customer: current_user)
              return render_result_error(result) if result.failure?

              render json: serialize_resource(result.value), status: :created
            end

            protected

            def model_class
              Spree::Transfer
            end

            def serializer_class
              Spree::Api::V3::Store::MembershipCardTransferSerializer
            end
          end
        end
      end
    end
  end
end
