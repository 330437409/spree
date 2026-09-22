class CreateSpreePointProducts < ActiveRecord::Migration[8.1]
  def change
    # A good in the points shop: what it costs, and what redeeming it issues.
    #
    # The row declares the thing — a coupon, a membership card, a shippable
    # good — and the plan that owns that thing issues it. `type` is the
    # discriminator and the keys are concrete columns rather than a polymorphic
    # source, which is the shape `Spree::CommissionLine` states: a polymorphic
    # pointer would let a row name a kind nothing can issue.
    create_table :spree_point_products do |t|
      t.references :store, null: false, index: false
      # Null means the whole store rather than one seller's shelf.
      t.references :seller, index: false
      t.string   :type, null: false
      t.string   :name, null: false
      t.string   :image
      # The operator's own flat shelf label, which the client reads as a
      # `typeCode` list: a field, not a second taxonomy.
      t.string   :category
      t.integer  :points, null: false, default: 0
      # Points are not the only price: a good may add money on top of them.
      t.decimal  :money, precision: 10, scale: 2, null: false, default: 0
      t.integer  :stock, null: false, default: 0
      t.integer  :position, null: false, default: 0
      t.boolean  :featured, null: false, default: false
      # What a redemption issues, one kind at a time. `coupon_campaign_id` is
      # a forward reference: the coupon wallet's row is what it will point at
      # (docs/plans/6.1-coupon-wallet.md).
      t.references :coupon_campaign, index: false
      t.references :customer_group, index: false
      t.references :variant, index: false
      # Who it is offered to, as conditions on the customer rather than on the
      # price.
      t.string   :limit_user_type
      t.boolean  :subscribe_site_wechat, null: false, default: false
      t.string   :we_chat_qr_code
      t.boolean  :site_equal, null: false, default: false
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :spree_point_products, [:store_id, :position],
              name: 'index_spree_point_products_on_store_and_position'
    add_index :spree_point_products, [:store_id, :category],
              name: 'index_spree_point_products_on_store_and_category'
    add_index :spree_point_products, [:store_id, :seller_id],
              name: 'index_spree_point_products_on_store_and_seller'
  end
end
