class CreateSpreeScenarioOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_scenario_orders do |t|
      t.references :store, null: false, index: false
      # Nullable: a purchase can be made before there is an account, and a
      # customer row is what a claim attaches to rather than what it needs.
      t.references :customer, null: true, index: false
      # Set only where the scenario genuinely delivers physical goods: what is
      # bought is then an ordinary order, linked from here.
      t.references :order, null: true, index: false
      t.string   :kind, null: false
      t.string   :payment_channel, null: false
      t.string   :status, null: false
      # Copied at creation rather than read off the kind afterwards, so the row
      # still explains itself when a price list changes.
      t.decimal  :amount, null: false, default: 0, precision: 10, scale: 2
      t.string   :currency, null: false
      # What the kind was told when it was bought, kept for the settlement and
      # for an operator looking at what went wrong.
      if t.respond_to?(:jsonb)
        t.jsonb :payload
      else
        t.json :payload
      end
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :spree_scenario_orders, [:store_id, :status]
    add_index :spree_scenario_orders, [:customer_id, :status]
    add_index :spree_scenario_orders, [:store_id, :kind]
  end
end
