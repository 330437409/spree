module Spree
  module Api
    module V3
      module Admin
        # The cards a store has issued, and what became of them.
        #
        # Read-only: a card records what happened, so the only write the surface
        # has is voiding one — a lost phone, a fraud report — which is its own
        # nested resource rather than an edit here.
        class MembershipCardsController < ResourceController
          scoped_resource :memberships

          protected

          def model_class
            Spree::MembershipCard
          end

          def serializer_class
            Spree::Api::V3::Admin::MembershipCardSerializer
          end

          def collection_includes
            %i[customer customer_group membership scenario_order]
          end

          def scope_includes
            collection_includes
          end
        end
      end
    end
  end
end
