module Spree
  module Api
    module V3
      module Store
        # The rights catalogue: every right this store's tiers carry, published
        # and unpublished alike, each with the tier it belongs to.
        #
        # The flat list is the model — the member centre's sections are a
        # projection of it — so this is the read a client that wants everything
        # starts from.
        class MembershipRightsController < ResourceController
          protected

          def model_class
            Spree::MembershipRight
          end

          def serializer_class
            Spree::Api::V3::MembershipRightSerializer
          end

          # Through the ladder, which is where the store is: a right carries no
          # tenancy column of its own, so this is built from the model rather
          # than from the base's store-scoped relation.
          def scope
            Spree::MembershipRight.for_store(current_store)
          end

          def apply_collection_sort(collection)
            collection.order(:position, :id)
          end

          def collection_includes
            [:tier_setting]
          end

          def scope_includes
            collection_includes
          end
        end
      end
    end
  end
end
