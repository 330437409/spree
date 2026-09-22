class AddSubsidyToSellerTransfers < ActiveRecord::Migration[8.1]
  def change
    # One reversal per refund *per row it reverses*. A refund that takes back
    # an earning also takes back the subsidy the platform added to it, and
    # each is its own row — so the refund alone can no longer be the key.
    remove_index :spree_seller_transfers, name: 'index_seller_transfers_on_refund'
    add_index :spree_seller_transfers, [:refund_id, :reversed_from_id], unique: true,
                                                                       name: 'index_seller_transfers_on_refund_and_reversed'

    # One subsidy per order, the mirror of the earning's own index: the
    # fulfillment event that writes it can fire more than once.
    if connection.supports_partial_index?
      add_index :spree_seller_transfers, :order_id, unique: true,
                                                    where: "kind = 'subsidy'",
                                                    name: 'index_seller_transfers_on_order_subsidy'
    else
      # Same shape as the earning's MySQL branch: null for anything that is
      # not a subsidy, which a unique index treats as distinct from every
      # other null. See the create migration.
      execute <<~SQL.squish
        ALTER TABLE spree_seller_transfers
        ADD COLUMN subsidy_key BIGINT
        AS (CASE WHEN kind = 'subsidy' THEN order_id ELSE NULL END) STORED
      SQL

      add_index :spree_seller_transfers, :subsidy_key, unique: true,
                                                       name: 'index_seller_transfers_on_order_subsidy'
    end
  end
end
