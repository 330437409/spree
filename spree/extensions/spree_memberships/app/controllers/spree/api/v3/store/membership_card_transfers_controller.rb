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
        #
        # Guest-reachable even on a login-gated store: this is the one screen a
        # gift shows before there is anybody to be signed in as.
        class MembershipCardTransfersController < ResourceController
          allow_guest_storefront_access!

          protected

          def model_class
            Spree::Transfer
          end

          def serializer_class
            Spree::Api::V3::Store::MembershipCardTransferSerializer
          end

          # The address is the token, not an id; the scope is the base's, so it
          # is the store that gave the gift, and a token from another storefront
          # is not found here. Any status: a window that lapsed or was taken back
          # is still what the link points at, and its own status is the answer —
          # only a token nobody holds is a 404.
          def find_resource
            scope.where(transferable_type: 'Spree::MembershipCard').find_by!(token: params[:token])
          end
        end
      end
    end
  end
end
