class CreateSpreeCouponWallet < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_coupon_campaigns do |t|
      t.references :store, null: false, index: false
      # The promotion whose codes this campaign hands over: a code belongs to
      # a promotion, and the campaign is what decides which one.
      t.references :promotion, null: false, index: false
      t.string   :name, null: false
      t.string   :type, null: false
      t.string   :status, null: false
      t.datetime :starts_at
      t.datetime :expires_at
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

    add_index :spree_coupon_campaigns, [:store_id, :status]
    add_index :spree_coupon_campaigns, [:store_id, :type]

    create_table :spree_coupon_holdings do |t|
      t.references :grant, null: false, index: false
      t.references :coupon_code, null: false, index: false
      t.references :campaign, null: true, index: false
      t.string   :source, null: false
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.datetime :deleted_at
      t.timestamps
    end

    # One grant is one holding, and one code is held once.
    add_index :spree_coupon_holdings, :grant_id, unique: true
    add_index :spree_coupon_holdings, :coupon_code_id, unique: true
    add_index :spree_coupon_holdings, [:campaign_id, :source]
  end
end
