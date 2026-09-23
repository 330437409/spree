class AddTermsToSpreeMembershipTierSettings < ActiveRecord::Migration[8.1]
  def change
    # The three pieces ported from `.custom-extensions/spree_crm`'s membership
    # plan rather than re-invented (ruled 2026-09-18): whether a term extends
    # itself when it ends, how long it may sit lapsed before it leaves the tier's
    # group, and the SKU the purchase is priced by — which here resolves to the
    # `vip` scenario kind rather than to an `order.placed` subscriber, since a
    # membership is never bought through a cart.
    add_column :spree_membership_tier_settings, :auto_renew, :boolean, null: false, default: false
    add_column :spree_membership_tier_settings, :grace_days, :integer, null: false, default: 0
    add_column :spree_membership_tier_settings, :sku, :string

    # Not unique in the database: a tier setting reaches its store through its
    # group, so there is no store column here to scope an index by. The model
    # validates it per store, which is how core keeps a variant's SKU apart
    # between sellers (Spree::Variant#validate_sku_uniqueness).
    add_index :spree_membership_tier_settings, :sku
  end
end
