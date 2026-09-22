class CreateSpreeLedgerEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_ledger_entries do |t|
      t.references :store, null: false, index: false
      # The points account, the distributor, the gift card — whatever holds
      # the balance this entry moved.
      t.references :account, polymorphic: true, null: false, index: false
      t.string   :kind, null: false
      # `points`, `growth_value` or a currency code: a balance is a sum
      # filtered by unit, never a number without one.
      t.string   :unit, null: false
      # Signed: a spend, an expiry and a reversal are negative. Wider than the
      # repository's money columns on purpose — a unit is points or
      # growth_value as often as it is a currency, and 10,2 would cap a points
      # balance at 99,999,999.
      t.decimal  :amount, precision: 20, scale: 6, null: false, default: 0
      # The account's own balance at this moment, where the account has no
      # balance column of its own. Null where the instrument is authoritative.
      t.decimal  :balance_after, precision: 20, scale: 6
      t.references :reverses_entry, index: true
      t.string   :idempotency_key, null: false
      t.references :source, polymorphic: true, index: false
      t.datetime :occurred_at, null: false
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.timestamps
    end

    # One account's history, in the order it happened. The account leads
    # because it is what every reader of this table constrains: the store sits
    # between the account and the time would leave the ordering unserved on
    # every engine but PostgreSQL.
    add_index :spree_ledger_entries, [:account_type, :account_id, :occurred_at],
              name: 'index_spree_ledger_entries_on_account_and_time'
    # The producer's key, and the reason a retried webhook is harmless. No
    # partial predicate and no `deleted_at`: an entry is never removed, only
    # reversed by another entry.
    add_index :spree_ledger_entries, [:account_type, :account_id, :idempotency_key],
              unique: true, name: 'index_spree_ledger_entries_on_account_and_key'
    add_index :spree_ledger_entries, [:source_type, :source_id],
              name: 'index_spree_ledger_entries_on_source'
    # `t.references :reverses_entry` above indexes it: a reversal is read by
    # the entry it undoes, and so is the question "has this been reversed".
  end
end
