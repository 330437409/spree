module Spree
  module Api
    module V3
      module Admin
        # The registry picker: what kinds of right this deployment can carry,
        # each with the settings it declares.
        #
        # Read-only discovery, and the reason a kind a gem adds appears in the
        # dashboard's picker without either of them being edited.
        class MembershipRightsController < ResourceController
          scoped_resource :memberships

          def types
            authorize! :read, Spree::MembershipRight

            render json: { data: Spree::MembershipRight.subclasses_with_preference_schema }
          end

          protected

          def model_class
            Spree::MembershipRight
          end

          # `types` is read-only discovery, so it maps to the read scope.
          def read_actions
            super + %w[types]
          end
        end
      end
    end
  end
end
