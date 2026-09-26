module Spree
  module Api
    module V3
      module Admin
        # The ladder an operator arranges: every tier this store runs, in rank
        # order, with the group each one is.
        #
        # A read of its own rather than a filter on the customer groups that
        # carry a tier: which groups those are is this gem's fact — core's group
        # serializer says nothing about it — and the ladder is what the operator's
        # screen is, in the order the store presents it. The group and the rights
        # come preloaded, so a store with many tiers is still a fixed number of
        # reads rather than one per rung.
        class MembershipTiersController < ResourceController
          scoped_resource :memberships

          protected

          def model_class
            Spree::MembershipTierSetting
          end

          def serializer_class
            Spree::Api::V3::Admin::MembershipTierSerializer
          end

          def apply_collection_sort(collection)
            collection.reorder(:rank, :id)
          end

          def collection_includes
            [:customer_group, :rights]
          end
        end
      end
    end
  end
end
