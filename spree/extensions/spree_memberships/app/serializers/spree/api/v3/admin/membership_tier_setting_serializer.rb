module Spree
  module Api
    module V3
      module Admin
        # What makes a customer group a tier, as the operator edits it.
        class MembershipTierSettingSerializer < BaseSerializer
          typelize rank: :number, threshold: 'string | null', validity_days: 'number | null',
                   rights_total: :number, member_discount_percentage: 'string | null',
                   display_threshold: 'string | null',
                   auto_renew: :boolean, grace_days: :number, sku: 'string | null',
                   preferences: 'Record<string, unknown> | null',
                   preference_schema: 'Array<{ key: string; type: string; default: unknown; choices?: string[] }>',
                   deleted_at: 'string | null'

          attributes :rank
          attribute(:threshold) { |setting| decimal_string(setting.threshold) }
          # The same figure as the operator reads it, in the store's currency —
          # a ladder column is read, not compared.
          attribute(:display_threshold) { |setting| setting.display_threshold&.to_s }
          attributes :validity_days
          # Ported from spree_crm's membership plan: whether a term extends
          # itself, how long it may sit lapsed, and the SKU the purchase is
          # priced by.
          attributes :auto_renew, :grace_days, :sku
          attribute(:rights_total) { |setting| Spree::MembershipRight.where(customer_group_id: setting.customer_group_id).count }
          # The member price this tier grants, as a percentage off the shelf
          # price. The operator sets it and the platform funds it.
          attribute(:member_discount_percentage) { |setting| decimal_string(setting.member_discount_percentage) }
          # What the tier says about itself to somebody who has not bought it
          # yet: the savings popup's copy, declared on the row as typed
          # preferences. The schema travels with the values so an operator's form
          # renders the fields — and their labels and defaults — without knowing
          # a single key.
          attribute :preferences, &:serialized_preferences
          attribute :preference_schema, &:serialized_preference_schema
          attributes :created_at, :updated_at, :deleted_at
        end
      end
    end
  end
end
