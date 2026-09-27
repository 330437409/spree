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

          # PATCH /api/v3/admin/membership_tiers/:id/reposition
          #
          # The ladder's order is the operator's and they arrange it by
          # dragging a rung, so a move carries the position it was dropped at
          # rather than a rank somebody kept in step: the service settles the
          # store's whole ladder into 1..n in one transaction
          # (`Spree::Memberships::RepositionTier`).
          def reposition
            tier = find_resource
            authorize! :update, tier

            position = integer_param(:new_position)
            return render_invalid_position if position.nil?

            result = Spree::Memberships::RepositionTier.call(
              tier_setting: tier, new_position: position
            )
            unless result.success?
              # The service's own words: a rung whose store cannot be reached is
              # something the operator can be told, and this gem already names it
              # (`config/locales/en.yml`, `memberships.errors`).
              return render_error(
                code: ERROR_CODES[:validation_error],
                message: Spree.t(result.error, scope: 'memberships.errors',
                                               default: 'This tier could not be moved.'),
                status: :unprocessable_content
              )
            end

            render json: serialize_resource(tier.reload)
          end

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
