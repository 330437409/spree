class AddPreferencesToSpreeMembershipTierSettings < ActiveRecord::Migration[8.1]
  def change
    # The table is opened only for the adapter check core itself uses here: only
    # PostgreSQL's table definition answers to `jsonb`.
    change_table :spree_membership_tier_settings do |t|
      # What a tier says about itself to somebody who has not bought it yet: the
      # copy the buy page's savings popup renders, declared with
      # `Spree::PreferenceSchema` so it is a typed schema an operator's form can
      # render rather than a blob (docs/plans/6.1-membership-tiers-and-rights.md).
      #
      # Nullable and undefaulted: the model's declarations supply the values a
      # fresh row reads, and a row nobody has written for says so.
      if t.respond_to?(:jsonb)
        add_column :spree_membership_tier_settings, :preferences, :jsonb
      else
        add_column :spree_membership_tier_settings, :preferences, :json
      end
    end
  end
end
