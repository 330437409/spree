class CreateFlashSales < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_flash_sales do |t|
      t.references :store, null: false
      t.references :seller, null: true
      t.string :title, null: false
      t.string :code, null: false
      t.string :status, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      # The pool's three scopes, as caps. Zero means nothing is left to sell,
      # not "unlimited": the client reads it the same way (a pool figure at or
      # below zero renders 已抢光).
      t.integer :pool_all, null: false, default: 0
      t.integer :pool_per_day, null: false, default: 0
      t.integer :pool_per_slot, null: false, default: 0
      t.integer :purchase_cap_all
      t.integer :purchase_cap_day
      t.string :audience
      t.boolean :allows_points, null: false, default: false
      t.boolean :allows_coupons, null: false, default: false
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.datetime :deleted_at
      t.timestamps
      t.index [:store_id, :status]
    end

    create_table :spree_flash_sale_slots do |t|
      t.references :flash_sale, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.integer :pool, null: false, default: 0
      t.integer :purchase_cap
      t.integer :position, null: false, default: 0
      t.timestamps
      t.index [:flash_sale_id, :position]
    end

    create_table :spree_flash_sale_items do |t|
      t.references :flash_sale, null: false
      t.references :variant, null: false
      t.decimal :sale_amount, null: false, default: 0, precision: 10, scale: 2
      t.integer :pool, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.timestamps
      t.index [:flash_sale_id, :variant_id], unique: true
    end

    # One row per scope of one activity's pool — all time, one day, one slot,
    # one item — carrying what has been claimed against it. The cap stays on the
    # record a merchant edits; the counter here is only what is held, because a
    # copied cap goes stale the moment it is edited.
    create_table :spree_flash_sale_pools do |t|
      t.references :flash_sale, null: false
      t.string :kind, null: false
      t.string :key, null: false
      t.date :on_date
      t.references :slot, null: true
      t.references :item, null: true
      t.integer :held, null: false, default: 0
      t.timestamps
      t.index [:flash_sale_id, :key], unique: true, name: 'index_spree_flash_sale_pools_on_sale_and_key'
    end

    create_table :spree_flash_sale_tickets do |t|
      t.references :store, null: false
      t.references :flash_sale, null: false
      t.references :flash_sale_slot, null: true
      t.references :variant, null: false
      t.references :customer, null: false
      t.integer :quantity, null: false
      t.string :status, null: false
      t.datetime :expires_at, null: false
      # Set while the ticket holds, cleared when it settles, expires, or is
      # replaced. A unique index over it is how "one live ticket per customer
      # per activity" is enforced by the database on every engine: a partial
      # index would say it more directly, and MySQL has none.
      t.string :active_key
      t.timestamps
      t.index :active_key, unique: true
      t.index [:customer_id, :status]
      # What the expiry sweep walks, and what a claim reads before counting.
      t.index [:status, :expires_at]
    end

    # The hold, and it knows a pool rather than a flash sale: a quantity, an
    # owner, a deadline and the moment it was released. Group buying lifts this
    # into core, which is why it is not shaped around this gem's activity.
    create_table :spree_pool_holds do |t|
      t.references :pool, null: false
      t.string :owner_type, null: false
      t.string :owner_id, null: false
      t.integer :quantity, null: false
      t.datetime :expires_at, null: false
      t.datetime :released_at
      t.string :status, null: false
      t.timestamps
      t.index [:owner_type, :owner_id]
      t.index [:status, :expires_at]
    end

    create_table :spree_flash_sale_reminders do |t|
      t.references :store, null: false
      t.references :flash_sale, null: false
      t.references :flash_sale_slot, null: false
      t.references :customer, null: false
      t.timestamps
      t.index [:flash_sale_slot_id, :customer_id], unique: true,
                                                   name: 'index_spree_flash_sale_reminders_on_slot_and_customer'
    end
  end
end
