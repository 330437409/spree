module Spree
  module Api
    module V3
      module Store
        # The recipient's read: what is waiting for them, before they sign in.
        #
        # Addressed by the token and nothing else — no customer, no card id — so
        # that opening a share link is not a way to walk somebody's wallet.
        # Deliberately not under `customers/me`: the transfer is the giver's, the
        # read is the recipient's.
        class MembershipCardTransfersController < Store::ResourceController
          # The address is the token, not an id: the base's loader has nothing to
          # resolve and would 404 on a param this route never sends.
          skip_before_action :set_resource, raise: false

          # GET /api/v3/store/membership_card_transfers/:token
          def show
            # Any status: a window that lapsed or was taken back is still what the
            # link points at, and its own status is the answer. Only a token
            # nobody holds is a 404.
            window = Spree::Transfer.find_by(token: params[:token])
            raise ActiveRecord::RecordNotFound if window.nil?

            render json: serialize_resource(window)
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
