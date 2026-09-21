class CreateSpreePaymentPins < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_payment_pins do |t|
      t.references :store, null: false
      t.references :customer, null: false
      t.string :pin_digest, null: false
      # The client's `display`: a PIN that exists may still not be asked for.
      t.boolean :required, null: false, default: true
      t.integer :failed_attempts, null: false, default: 0
      t.datetime :locked_until
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :spree_payment_pins, [:store_id, :customer_id], unique: true
  end
end
