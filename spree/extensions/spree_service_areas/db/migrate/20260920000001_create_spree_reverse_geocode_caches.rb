class CreateSpreeReverseGeocodeCaches < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_reverse_geocode_caches do |t|
      # The key: one cell of the world, as one provider answered it, under one
      # coordinate system and one release of the tree. Any of the four changing
      # is a different question, so none of them is an invalidation to sweep.
      t.string :geohash, null: false
      t.string :provider, null: false
      t.string :coordinate_system, null: false
      t.string :dataset_version, null: false

      # What it answered. A point that resolved to nothing is cached too — those
      # are the expensive ones, because every request for them hits the provider
      # otherwise — which is what `resolved` says.
      t.boolean :resolved, null: false, default: false
      t.string :province_code
      t.string :city_code
      t.string :district_code
      t.string :township_code

      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :spree_reverse_geocode_caches,
              [:provider, :coordinate_system, :dataset_version, :geohash],
              unique: true,
              name: 'index_spree_reverse_geocode_caches_on_lookup'
    add_index :spree_reverse_geocode_caches, :expires_at
  end
end
