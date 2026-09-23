class CreateSpreeTransfers < ActiveRecord::Migration[8.1]
  def change
    # One row for "this thing is on its way to someone": a coupon holding, a gift
    # card or a membership card. The journey is what the three domains share —
    # the token, the window, the three endings — while what moves stays theirs
    # (docs/plans/6.1-transfer-primitive.md).
    create_table :spree_transfers do |t|
      t.references :store, null: false, index: false
      t.references :transferable, polymorphic: true, null: false, index: false
      # Who gave it, and who received it — nil until somebody claims it.
      t.references :from_customer, null: false, index: false
      t.references :to_customer, index: false
      # Where the gift was sent: the address, not an account.
      t.string :to_phone
      t.string :status, null: false # pending / accepted / canceled — never expired
      # Opaque, and never derived from the thing it carries: a public read makes
      # the address a bearer capability.
      t.string :token, null: false
      t.string :message
      t.datetime :accepted_at
      t.datetime :canceled_at
      t.datetime :expires_at
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :spree_transfers, :store_id
    add_index :spree_transfers, [:from_customer_id, :status]
    add_index :spree_transfers, [:to_customer_id, :status]
    add_index :spree_transfers, [:status, :expires_at]
    add_index :spree_transfers, :token, unique: true

    add_one_pending_window_index
  end

  private

  # One pending transfer per thing: a double tap must not open two claim windows
  # on one card. Partial where the adapter has partial indexes, over a stored key
  # where it does not — the shape core's seller transfers and the membership
  # gem's terms already use.
  def add_one_pending_window_index
    if connection.supports_partial_index?
      add_index :spree_transfers, [:transferable_type, :transferable_id], unique: true,
                    where: "status = 'pending' AND deleted_at IS NULL",
                    name: 'index_spree_transfers_on_transferable_while_pending'
    else
      execute <<~SQL.squish
        ALTER TABLE spree_transfers
        ADD COLUMN pending_key VARCHAR(255)
        AS (CASE WHEN status = 'pending' AND deleted_at IS NULL
                 THEN CONCAT(transferable_type, '-', transferable_id) ELSE NULL END) STORED
      SQL

      add_index :spree_transfers, :pending_key, unique: true,
                    name: 'index_spree_transfers_on_transferable_while_pending'
    end
  end
end
