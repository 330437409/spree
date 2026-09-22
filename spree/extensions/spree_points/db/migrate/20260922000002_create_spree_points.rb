class CreateSpreePoints < ActiveRecord::Migration[8.1]
  def change
    # One row per (store, customer, balance kind), and the row a spend locks.
    # No balance column: the balance is the sum of usable lots' `remaining`,
    # because expiry is a date fact and nothing flips a status, so a stored
    # total would drift from the truth between an expiry and the next writer.
    create_table :spree_point_accounts do |t|
      t.references :store, null: false, index: false
      t.references :customer, null: false, index: false
      t.string  :kind, null: false
      # Kept for the lock to be worth taking, and for the one screen that reads
      # a total; the growth value read exposes the current value alone.
      t.integer :lifetime_earned, null: false, default: 0
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.timestamps
    end

    add_index :spree_point_accounts, [:store_id, :customer_id, :kind],
              unique: true, name: 'index_spree_point_accounts_on_customer_and_kind'

    # The operator's reason vocabulary: a row, not a constant, so a fifth
    # reason is an operator action rather than a client release.
    create_table :spree_point_reasons do |t|
      t.references :store, null: false, index: false
      t.string  :key, null: false
      t.string  :label, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :spree_point_reasons, [:store_id, :key], unique: true,
              name: 'index_spree_point_reasons_on_store_and_key'

    # The lot, as the side table of a core `spree_grants` row: the primitive
    # owns the owner, the source, `granted_at`, `expires_at` and the status,
    # and this table owns what only a lot has — how much of it is left, and
    # why the operator granted it.
    create_table :spree_point_grants do |t|
      t.references :grant, null: false, index: false
      t.references :account, null: false, index: false
      t.references :reason, index: false
      t.integer :amount, null: false, default: 0
      t.integer :remaining, null: false, default: 0
      t.timestamps
    end

    add_index :spree_point_grants, :grant_id, unique: true,
              name: 'index_spree_point_grants_on_grant'
    add_index :spree_point_grants, :account_id,
              name: 'index_spree_point_grants_on_account'

    # Which lots a debit drew from: the audit trail, and the basis of a
    # reversal. Not the reason `remaining` is knowable — the lot keeps that.
    create_table :spree_point_allocations do |t|
      t.references :ledger_entry, null: false, index: false
      t.references :point_grant, null: false, index: false
      t.integer :amount, null: false, default: 0
      t.timestamps
    end

    add_index :spree_point_allocations, [:ledger_entry_id, :point_grant_id],
              name: 'index_spree_point_allocations_on_entry_and_grant'
    add_index :spree_point_allocations, :point_grant_id,
              name: 'index_spree_point_allocations_on_grant'
  end
end
