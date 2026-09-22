module Spree
  module Api
    module V3
      module Admin
        module CustomerGroups
          # What makes a customer group a tier: one row per group, which is why
          # its three actions are written out rather than inherited — the base's
          # shape is a collection, and a group has at most one of these.
          # Everything else the base provides still applies: the authorization,
          # the error shape and the renderer.
          class TierSettingsController < ResourceController
            scoped_resource :memberships

            # The route names no id — a group has one of these — so the base's
            # loader has nothing to resolve and each action authorizes what it
            # acts on.
            skip_before_action :set_resource, raise: false

            prepend_before_action :set_customer_group
            before_action :set_setting, only: [:show, :update]

            def show
              authorize_resource!(@setting, :show)

              render json: serialize_resource(@setting)
            end

            def create
              @setting = Spree::MembershipTierSetting.new(
                permitted_params.merge(customer_group: @customer_group)
              )
              authorize_resource!(@setting, :create)

              save_and_render(@setting, status: :created)
            end

            def update
              authorize_resource!(@setting, :update)
              @setting.assign_attributes(permitted_params)

              save_and_render(@setting)
            end

            # A group that is not a tier is answered 404 rather than as an empty
            # one: nothing is what the caller asked for only if there is nothing
            # to ask about.
            def set_setting
              @setting = Spree::MembershipTierSetting.find_by(customer_group: @customer_group)
              raise ActiveRecord::RecordNotFound if @setting.nil?
            end

            protected

            def model_class
              Spree::MembershipTierSetting
            end

            def serializer_class
              Spree::Api::V3::Admin::MembershipTierSettingSerializer
            end

            def permitted_params
              params.permit(*model_additional_permitted_attributes, :rank, :threshold, :validity_days,
                            :member_discount_percentage)
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
