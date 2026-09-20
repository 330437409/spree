class CreateProductBundles < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_product_bundles do |t|
      t.references :store, null: false
      # The one seller every component must belong to, refused at save time —
      # a cross-seller bundle has no home in the marketplace's seller split.
      t.references :seller
      t.string :title, null: false
      t.string :slug, null: false
      t.string :status, null: false
      t.integer :position, null: false, default: 0
      # The bundle's own preferences — its discount rule — the way every Spree
      # model keeps them.
      t.text :preferences
      t.timestamps
      t.datetime :deleted_at

      t.index [:store_id, :slug], unique: true, name: 'index_spree_product_bundles_on_store_and_slug'
      t.index [:store_id, :status, :position]
      t.index :deleted_at
    end

    create_table :spree_bundle_components do |t|
      t.references :bundle, null: false
      # The component is an offer variant, so the bundle's lines carry the
      # seller and the price the variant already has.
      t.references :variant, null: false
      t.integer :quantity, null: false, default: 1
      t.timestamps

      t.index [:bundle_id, :variant_id], unique: true, name: 'index_spree_bundle_components_on_bundle_and_variant'
    end

    create_table :spree_bundle_line_items do |t|
      t.references :bundle, null: false
      t.references :line_item, null: false
      t.timestamps

      t.index :line_item_id, unique: true, name: 'index_spree_bundle_line_items_on_line_item'
    end
  end
end
