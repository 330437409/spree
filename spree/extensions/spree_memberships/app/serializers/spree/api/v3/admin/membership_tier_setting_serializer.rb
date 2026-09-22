module Spree
  module Api
    module V3
      module Admin
        # What makes a customer group a tier, as the operator edits it.
        class MembershipTierSettingSerializer < BaseSerializer
          typelize rank: :number, threshold: 'string | null', validity_days: 'number | null',
                   rights_total: :number

          attributes :rank
          attribute(:threshold) { |setting| decimal_string(setting.threshold) }
          attributes :validity_days
          attribute(:rights_total) { |setting| Spree::MembershipRight.where(customer_group_id: setting.customer_group_id).count }
          attributes :created_at, :updated_at, :deleted_at
        end
      end
    end
  end
end
