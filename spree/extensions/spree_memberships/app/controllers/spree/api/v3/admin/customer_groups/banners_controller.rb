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
          end
        end
      end
    end
  end
end
