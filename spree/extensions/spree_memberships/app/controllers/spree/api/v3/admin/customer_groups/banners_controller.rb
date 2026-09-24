module Spree
  module Api
    module V3
      module Admin
        module CustomerGroups
          # The banner a tier's members see: one row per group, written the way
          # the group's settings row is (`BaseController`).
          #
          # The parameters are deliberately NOT normalized, as the payment
          # methods controller's are not: a target's `link` is an opaque string a
          # merchant typed, and normalization decodes anything shaped like a
          # prefixed id.
          class BannersController < BaseController
            before_action :ensure_areas_are_targets, only: [:create, :update]

            protected

            def model_class
              Spree::MembershipBanner
            end

            def serializer_class
              Spree::Api::V3::Admin::MembershipBannerSerializer
            end

            def permitted_params
              params.permit(*model_additional_permitted_attributes, :name, :pic,
                            areas: [:area_rem, :link, :name])
            end

            private

            # Permitted parameters drop an `areas` they cannot permit, so a
            # payload that named tap targets and sent something else would be
            # saved as a banner with none — the operator answered 201, the
            # picture with nothing over it. Refused instead, naming the field.
            def ensure_areas_are_targets
              return if params[:areas].blank?

              targets = params[:areas]
              # The shapes a target can be: what a request hands over is
              # `ActionController::Parameters`, which is not a Hash — and every
              # Array responds to `to_h`, so a list of lists must not pass.
              return if targets.is_a?(Array) && targets.all? { |target|
                target.is_a?(Hash) || target.is_a?(ActionController::Parameters)
              }

              render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error],
                message: Spree.t('memberships.errors.banner_areas_invalid'),
                status: :unprocessable_content
              )
            end
          end
        end
      end
    end
  end
end
