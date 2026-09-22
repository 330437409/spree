class AddAttributionToSpreeLedgerEntries < ActiveRecord::Migration[8.1]
  def change
    # Who the movement belongs to, beside what caused it: `source` points at
    # reviews and adjustments as readily as at orders, and neither has a
    # seller. Ruled 2026-09-22 (docs/plans/6.1-points-and-growth-value.md).
    add_column :spree_ledger_entries, :seller_id, :bigint
    add_column :spree_ledger_entries, :order_id, :bigint

    add_index :spree_ledger_entries, [:seller_id, :occurred_at],
              name: 'index_spree_ledger_entries_on_seller_and_time'
    add_index :spree_ledger_entries, :order_id,
              name: 'index_spree_ledger_entries_on_order'
  end
end
