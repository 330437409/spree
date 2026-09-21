class CreateSpreeGrants < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_grants do |t|
      t.references :store, null: false, index: false
      # Null while the thing is owed to nobody yet: a campaign's coupon sits
      # unclaimed until someone draws it.
      t.references :customer, index: false
      t.string   :kind, null: false
      t.string   :status, null: false
      t.string   :idempotency_key, null: false
      t.string   :source_type
      t.string   :source_id
      t.string   :issued_type
      t.string   :issued_id
      t.datetime :granted_at, null: false
      t.datetime :expires_at
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.datetime :deleted_at
      t.timestamps
    end

    # The key is the kind's own, so this is the index that makes a job running
    # twice harmless. A deleted row keeps its key: the key says the debt was
    # recorded, and removing a row is not a reason to record it a second time.
    add_index :spree_grants, [:store_id, :kind, :idempotency_key],
              unique: true, name: 'index_spree_grants_on_store_kind_and_key'
    # What a customer's own list reads, and what an expiry warning walks.
    add_index :spree_grants, [:customer_id, :status, :expires_at],
              name: 'index_spree_grants_on_customer_status_and_expiry'
  end
end
