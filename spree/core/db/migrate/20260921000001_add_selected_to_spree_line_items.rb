class AddSelectedToSpreeLineItems < ActiveRecord::Migration[8.1]
  def change
    # Whether a cart line takes part in checkout. A line is ticked when it is
    # added, and only ticked lines are copied into an order at completion — so
    # an order never holds an unticked one, and the column's reach is the cart
    # (docs/plans/6.1-store-api-miniprogram-gaps.md).
    add_column :spree_line_items, :selected, :boolean, null: false, default: true
    add_index :spree_line_items, [:cart_id, :selected]
  end
end
