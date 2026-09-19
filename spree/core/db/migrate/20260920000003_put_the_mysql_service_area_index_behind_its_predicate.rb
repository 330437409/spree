class PutTheMysqlServiceAreaIndexBehindItsPredicate < ActiveRecord::Migration[8.1]
  # MySQL has no partial indexes, so the migration that added the binding took
  # the plain unique index its API-key migration takes elsewhere — and that is
  # stricter than the rule it stands for. The rule is *one active binding per
  # node*; a plain index also refuses a second binding on a node whose first one
  # was deactivated or deleted, and releasing the node that way is half of what
  # the rule means. A merchant who moved a shop would be told the area was taken
  # by their own retired row.
  #
  # A stored generated column is how MySQL emulates the predicate: it holds the
  # node only while the row is an active, undeleted binding, and a unique index
  # over it ignores the NULLs. The other engines already have the real thing
  # under this same index name.
  def up
    return unless Spree.mysql?

    remove_index :spree_stock_locations, name: 'index_spree_stock_locations_on_service_area'

    execute <<~SQL
      ALTER TABLE spree_stock_locations
      ADD COLUMN active_administrative_division_id bigint
      GENERATED ALWAYS AS (IF(active = 1 AND deleted_at IS NULL, administrative_division_id, NULL)) STORED
    SQL

    add_index :spree_stock_locations, :active_administrative_division_id,
              unique: true, name: 'index_spree_stock_locations_on_active_service_area'
  end

  def down
    return unless Spree.mysql?

    remove_index :spree_stock_locations, name: 'index_spree_stock_locations_on_active_service_area'
    remove_column :spree_stock_locations, :active_administrative_division_id
    add_index :spree_stock_locations, :administrative_division_id,
              unique: true, name: 'index_spree_stock_locations_on_service_area'
  end
end
