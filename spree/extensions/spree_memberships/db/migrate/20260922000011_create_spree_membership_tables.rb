class CreateSpreeMembershipTables < ActiveRecord::Migration[8.1]
  def change
    # What makes a `Spree::CustomerGroup` a tier rather than any other audience:
    # its rung on the ladder and what qualifies for it. The row has no name and
    # no member list, because the group it hangs from has both.
    create_table :spree_membership_tier_settings do |t|
      t.references :customer_group, null: false, index: false
      t.integer  :rank, null: false
      # Nullable: a tier nobody qualifies for by spending is one the operator
      # sells or grants, and a zero would say "everybody qualifies".
      t.decimal  :threshold, precision: 10, scale: 2
      t.integer  :validity_days
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.datetime :deleted_at
      t.timestamps
    end

    add_tier_setting_uniqueness_index

    # What a tier grants. STI on `type`, exactly as commission rules and
    # promotion actions are: a kind carries its own settings as preferences, so
    # a new kind is a class and a registration rather than a column.
    create_table :spree_membership_rights do |t|
      t.references :customer_group, null: false, index: false
      t.string   :type, null: false
      t.integer  :position, null: false, default: 0
      t.string   :name
      t.string   :image_url
      t.string   :badge
      t.text     :description
      t.boolean  :published, null: false, default: false
      if t.respond_to?(:jsonb)
        t.jsonb :preferences
      else
        t.json :preferences
      end
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :spree_membership_rights, [:customer_group_id, :position]

    add_right_uniqueness_index
  end

  # One right of each kind per tier, among live rows only — a retired row is
  # history, and a replacement is saved before the row it supersedes is retired.
  # Written the way `spree_commission_rules` writes the same rule: MySQL has no
  # partial indexes, so it gets a generated key column and everyone else gets the
  # predicate.
  # One settings row per group, among live rows — written the same way as the
  # rights index below, for the same reason: MySQL has no partial indexes.
  def add_tier_setting_uniqueness_index
    if Spree.mysql?
      reversible do |dir|
        dir.up do
          execute <<~SQL.squish
            ALTER TABLE spree_membership_tier_settings
            ADD COLUMN customer_group_key INT
            AS (IF(deleted_at IS NULL, customer_group_id, NULL)) STORED
          SQL
          add_index :spree_membership_tier_settings, :customer_group_key,
                    unique: true, name: 'index_membership_tier_settings_on_group'
        end

        dir.down do
          remove_index :spree_membership_tier_settings, name: 'index_membership_tier_settings_on_group'
          remove_column :spree_membership_tier_settings, :customer_group_key
        end
      end
    else
      add_index :spree_membership_tier_settings, :customer_group_id,
                unique: true, where: 'deleted_at IS NULL',
                name: 'index_membership_tier_settings_on_group'
    end
  end

  def add_right_uniqueness_index
    if Spree.mysql?
      reversible do |dir|
        dir.up do
          execute <<~SQL.squish
            ALTER TABLE spree_membership_rights
            ADD COLUMN type_key VARCHAR(255)
            AS (IF(deleted_at IS NULL, type, NULL)) STORED
          SQL
          add_index :spree_membership_rights, [:customer_group_id, :type_key],
                    unique: true, name: 'index_membership_rights_on_group_and_type'
        end

        dir.down do
          remove_index :spree_membership_rights, name: 'index_membership_rights_on_group_and_type'
          remove_column :spree_membership_rights, :type_key
        end
      end
    else
      add_index :spree_membership_rights, [:customer_group_id, :type],
                unique: true, where: 'deleted_at IS NULL',
                name: 'index_membership_rights_on_group_and_type'
    end
  end
end
