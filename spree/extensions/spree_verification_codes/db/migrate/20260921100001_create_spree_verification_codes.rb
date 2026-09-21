class CreateSpreeVerificationCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_verification_codes do |t|
      t.references :store, null: false
      # Digits only, no country code: a code is keyed by the number, including
      # one that belongs to nobody yet.
      t.string :phone, null: false
      # `account` or `payment` — the two families the client's own routes
      # separate, and no finer, because its verify endpoint cannot tell them
      # apart.
      t.string :purpose, null: false
      t.string :channel, null: false
      t.string :code_digest, null: false
      t.integer :attempts, null: false, default: 0
      t.datetime :expires_at, null: false
      t.datetime :verified_at
      t.datetime :consumed_at
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :spree_verification_codes, [:phone, :purpose, :expires_at]
  end
end
