class AddServiceAreaToSpreeStockLocations < ActiveRecord::Migration[8.1]
  def change
    change_table :spree_stock_locations do |t|
      # The warehouse's service area: an administrative node at any level, with
      # an optional polygon that narrows it. The coordinates are the warehouse's
      # own position, geocoded from its address columns
      # (docs/plans/6.1-seller-service-area-routing.md).
      t.bigint :administrative_division_id
      if t.respond_to? :jsonb
        t.jsonb :polygon
        t.jsonb :polygon_bbox
      else
        t.json :polygon
        t.json :polygon_bbox
      end
      t.decimal :latitude
      t.decimal :longitude
      t.datetime :geocoded_at
      t.string :geocode_provider
      t.string :geocode_status
    end

    # One active warehouse per node. `deleted_at IS NULL` belongs in the
    # predicate because a stock location is paranoid: a soft-deleted row that
    # never flipped `active` would otherwise hold its node forever, invisible to
    # the candidate query and impossible to rebind. Deactivating a warehouse is
    # therefore also what releases its node for a different seller.
    #
    # MySQL has no partial indexes, and this migration first settled for the
    # plain unique index core's API-key migration takes — which turned out to be
    # stricter than the rule. The next migration puts it behind a stored
    # generated column so all three engines mean the same thing by it.
    if ActiveRecord::Base.connection.adapter_name == 'Mysql2'
      add_index :spree_stock_locations, :administrative_division_id,
                unique: true, name: 'index_spree_stock_locations_on_service_area'
    else
      add_index :spree_stock_locations, :administrative_division_id,
                unique: true, name: 'index_spree_stock_locations_on_active_service_area',
                where: 'active = TRUE AND deleted_at IS NULL AND administrative_division_id IS NOT NULL'
    end
  end
end
