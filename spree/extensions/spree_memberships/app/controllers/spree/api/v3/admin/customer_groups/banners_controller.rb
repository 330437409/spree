module Spree
  module Api
    module V3
      module Admin
        module CustomerGroups
          # The banner a tier's members see. Written the way the tier's settings
          # are — a group has at most one of these, so its actions are written
          # out rather than inherited — and a group without one is answered 404
          # rather than as an empty banner, because nothing is the truth only
          # once somebody asked for it.
          class BannersController < ResourceController
            scoped_resource :memberships

            # The route names no id — a group has one of these — so the base's
            # loader has nothing to resolve and each action authorizes what it
            # acts on.
            skip_before_action :set_resource, raise: false

            prepend_before_action :set_customer_group
            before_action :set_banner, only: [:show, :update]

            def show
              authorize_resource!(@banner, :show)

              render json: serialize_resource(@banner)
            end

            def create
              @banner = Spree::MembershipBanner.new(
                banner_attributes.merge(customer_group: @customer_group)
              )
              authorize_resource!(@banner, :create)

              save_and_render(@banner, status: :created)
            end

            def update
              authorize_resource!(@banner, :update)
              @banner.assign_attributes(banner_attributes)

              save_and_render(@banner)
            end

            def set_banner
              @banner = Spree::MembershipBanner.find_by(customer_group: @customer_group)
              raise ActiveRecord::RecordNotFound if @banner.nil?
            end

            protected

            def model_class
              Spree::MembershipBanner
            end

            def serializer_class
              Spree::Api::V3::Admin::MembershipBannerSerializer
            end

            # Deliberately NOT routed through `normalize_params`, as the payment
            # methods controller is not: an area's `link` is an opaque string a
            # merchant typed, and normalization would decode one that happens to
            # look like a prefixed id.
            def permitted_params
              params.permit(*model_additional_permitted_attributes, :name, :pic,
                            areas: [:area_rem, :link, :name])
            end

            def set_customer_group
              @customer_group = Spree::CustomerGroup.for_store(current_store).
                                find_by_prefix_id!(params[:customer_group_id])
            end

            private

            # The permitted parameters as the column stores them: what a request
            # carries is `ActionController::Parameters`, which is not what a JSON
            # column should hold.
            def banner_attributes
              attributes = permitted_params.to_h.symbolize_keys
              attributes[:areas] = attributes[:areas].map(&:to_h) if attributes[:areas].present?

              attributes
            end
          end
        end
      end
    end
  end
end
