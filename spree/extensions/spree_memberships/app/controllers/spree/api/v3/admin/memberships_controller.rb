module Spree
  module Api
    module V3
      module Admin
        # Who holds which tier, and until when.
        #
        # Read-only: a term is written by a card's activation and moved by the
        # sweep, both of which answer a question an operator editing a row here
        # would not be asking.
        class MembershipsController < ResourceController
          scoped_resource :memberships

          protected

          def model_class
            Spree::Membership
          end

          def serializer_class
            Spree::Api::V3::Admin::MembershipSerializer
          end

          def collection_includes
            %i[customer customer_group card]
          end

          def scope_includes
            collection_includes
          end
        end
      end
    end
  end
end
