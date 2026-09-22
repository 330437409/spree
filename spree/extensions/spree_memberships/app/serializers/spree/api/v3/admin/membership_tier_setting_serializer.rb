module Spree
  module Api
    module V3
      module Admin
        # What makes a customer group a tier, as the operator edits it.
        class MembershipTierSettingSerializer < BaseSerializer
          typelize rank: :number, threshold: 'string | null', validity_days: 'number | null',
                   rights_total: :number, member_discount_percentage: 'string | null'

          attributes :rank
          attribute(:threshold) { |setting| decimal_string(setting.threshold) }
          attributes :validity_days
          attribute(:rights_total) { |setting| Spree::MembershipRight.where(customer_group_id: setting.customer_group_id).count }
          # The member price this tier grants, as a percentage off the shelf
          # price. The operator sets it and the platform funds it.
          attribute(:member_discount_percentage) { |setting| decimal_string(setting.member_discount_percentage) }
          attributes :created_at, :updated_at, :deleted_at
        end
      end
    end
  end
end
