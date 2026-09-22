module Spree
  module Api
    module V3
      module Admin
        module CustomerGroups
          # The rights a tier carries: the kind is chosen per request from the
          # registry and its configuration is its own preferences, so a kind a
          # gem adds is editable here with no change to this file.
          class MembershipRightsController < ResourceController
            include Spree::Api::V3::Admin::SubclassedResource

            scoped_resource :memberships

            subclassed_via -> { SpreeMemberships.membership_rights },
                           unknown_type_error: 'unknown_membership_right_type'

            protected

            def model_class
              Spree::MembershipRight
            end

            def serializer_class
              Spree::Api::V3::Admin::MembershipRightSerializer
            end

            def permitted_params
              params.permit(*model_additional_permitted_attributes, :type, :name, :description,
                            :badge, :image_url, :position, :published, preferences: {})
            end

            def set_parent
              @parent = Spree::CustomerGroup.for_store(current_store).
                        find_by_prefix_id!(params[:customer_group_id])
            end

            # The rights hang from the tier's group, and the group is core's —
            # it has no association to this gem's rows — so the parent is
            # attached here rather than built through it.
            def build_subclassed_resource(klass, attrs)
              klass.new(attrs.merge(customer_group: @parent))
            end

            def scope
              Spree::MembershipRight.where(customer_group_id: @parent.id)
            end
          end
        end
      end
    end
  end
end
