class CreateSpreeMembershipBanners < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_membership_banners do |t|
      t.references :customer_group, null: false, index: false
      t.string :name
      # The picture as a URL: a member centre's banner is served from the
      # merchant's own CDN, and the client renders it as a background image.
      t.string :pic, null: false
      # The tap targets laid over the picture, each one a style in rem — the unit
      # the client lays them out in — and the link it opens.
      if t.respond_to?(:jsonb)
        t.jsonb :areas, null: false
      else
        t.json :areas, null: false
      end
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.datetime :deleted_at
      t.timestamps
    end

    add_banner_uniqueness_index
  end

  # One banner per tier, among live rows — written the way the tier settings and
  # the rights write the same rule: MySQL has no partial indexes, so it gets a
  # generated key column and everyone else gets the predicate.
  def add_banner_uniqueness_index
    if Spree.mysql?
      reversible do |dir|
        dir.up do
          execute <<~SQL.squish
            ALTER TABLE spree_membership_banners
            ADD COLUMN customer_group_key INT
            AS (IF(deleted_at IS NULL, customer_group_id, NULL)) STORED
          SQL
          add_index :spree_membership_banners, :customer_group_key,
                    unique: true, name: 'index_membership_banners_on_group'
        end

        dir.down do
          remove_index :spree_membership_banners, name: 'index_membership_banners_on_group'
          remove_column :spree_membership_banners, :customer_group_key
        end
      end
    else
      add_index :spree_membership_banners, :customer_group_id,
                unique: true, where: 'deleted_at IS NULL',
                name: 'index_membership_banners_on_group'
    end
  end
end
