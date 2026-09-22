class AddCatalogToSpreeMembershipTierSettings < ActiveRecord::Migration[8.1]
  def change
    # The catalog this tier prices through, when it grants a member price.
    # Named on the tier rather than looked up through its group's assignments:
    # a group can be shown a B2B agreement as well, and the member price must
    # not land on that catalog's list.
    add_column :spree_membership_tier_settings, :catalog_id, :bigint
    add_index :spree_membership_tier_settings, :catalog_id
  end
end
