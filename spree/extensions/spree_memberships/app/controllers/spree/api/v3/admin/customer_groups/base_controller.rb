module Spree
  module Api
    module V3
      module Admin
        module CustomerGroups
          # What the rows a group has at most one of share: the group they hang
          # from, the three actions they answer, and the refusal when there is
          # nothing to answer with.
          #
          # The base's own shape is a collection, so the actions are written out
          # rather than inherited — but they are written out once, for every row
          # a group has one of. Everything else the base provides still applies:
          # the authorization, the error shape and the renderer.
          class BaseController < ResourceController
            scoped_resource :memberships

            # The route names no id — a group has one of these — so the base's
            # loader has nothing to resolve and each action authorizes what it
            # acts on.
            skip_before_action :set_resource, raise: false

            prepend_before_action :set_customer_group
            before_action :set_resource_from_group, only: [:show, :update]

            def show
              authorize_resource!(@resource, :show)

              render json: serialize_resource(@resource)
            end

            def create
              @resource = model_class.new(permitted_params.merge(customer_group: @customer_group))
              authorize_resource!(@resource, :create)

              save_and_render(@resource, status: :created)
            end

            def update
              authorize_resource!(@resource, :update)
              @resource.assign_attributes(permitted_params)

              save_and_render(@resource)
            end

            private

            # A group that has none is answered 404 rather than as an empty row:
            # nothing is what the caller asked for only if there is nothing to
            # ask about.
            def set_resource_from_group
              @resource = model_class.find_by(customer_group: @customer_group)
              raise ActiveRecord::RecordNotFound if @resource.nil?
            end

            def set_customer_group
              @customer_group = Spree::CustomerGroup.for_store(current_store).
                                find_by_prefix_id!(params[:customer_group_id])
            end
          end
        end
      end
    end
  end
end
