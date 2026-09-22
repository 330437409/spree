module Spree
  module Api
    module V3
      module Store
        # The ladder: every tier this store runs, in rank order, with what each
        # carries.
        #
        # Authenticated, because the client only calls it behind a token check —
        # the sales page renders from the buy page's own package list rather
        # than from here.
        class MembershipTiersController < ResourceController
          prepend_before_action :require_authentication!

          protected

          def model_class
            Spree::MembershipTierSetting
          end

          def serializer_class
            Spree::Api::V3::Store::MembershipTierSerializer
          end

          def scope
            super.for_store(current_store)
          end

          def apply_collection_sort(collection)
            collection.reorder(:rank, :id)
          end

          # The rights are counted by the serializer from their own table: the
          # group is core's and has no association to this gem's rows.
          def collection_includes
            [:customer_group]
          end

          def scope_includes
            collection_includes
          end
        end
      end
    end
  end
end
