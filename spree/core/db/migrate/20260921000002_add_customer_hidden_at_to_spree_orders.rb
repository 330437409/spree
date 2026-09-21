class AddCustomerHiddenAtToSpreeOrders < ActiveRecord::Migration[8.1]
  def change
    # When the customer took this order off their own list. The row stays —
    # the merchant's views, fulfillment, refunds and reporting are untouched —
    # so this is a preference about the customer's own history, not a soft
    # delete (docs/plans/6.1-store-api-miniprogram-gaps.md).
    add_column :spree_orders, :customer_hidden_at, :datetime
  end
end
