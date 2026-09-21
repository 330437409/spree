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
      # jsonb on PostgreSQL (binary, indexable); json on MySQL/SQLite.
      t.respond_to?(:jsonb) ? t.jsonb(:metadata) : t.json(:metadata)
      t.timestamps
    end

    # The one query this table has: the newest code for a store, number and
    # purpose. Leading with the store because every read is store-scoped, and
    # ending with created_at because the reads order by it.
    add_index :spree_verification_codes, [:store_id, :phone, :purpose, :created_at]
  end
end
