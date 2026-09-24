module Spree
  module Api
    module V3
      module Admin
        module CustomerGroups
          # What makes a customer group a tier: one row per group, and the shape
          # it is written in lives with the others a group has one of
          # (`BaseController`).
          class TierSettingsController < BaseController
            protected

            def model_class
              Spree::MembershipTierSetting
            end

            def serializer_class
              Spree::Api::V3::Admin::MembershipTierSettingSerializer
            end

            def permitted_params
              params.permit(*model_additional_permitted_attributes, :rank, :threshold, :validity_days,
                            :member_discount_percentage, :auto_renew, :grace_days, :sku,
                            preferences: {})
            end
          end
        end
      end
    end
  end
end
