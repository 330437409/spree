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
            Spree::Api::V3::MembershipTierSerializer
          end

          def apply_collection_sort(collection)
            collection.reorder(:rank, :id)
          end

          # The group each rung is, and the rights it counts: both hang off the
          # group rather than off this row, so both are preloaded and a ladder
          # stays a fixed number of reads.
          def collection_includes
            [:customer_group, :rights]
          end
        end
      end
    end
  end
end
