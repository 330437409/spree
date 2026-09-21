class AddChosenPromotionToSpreeLineItems < ActiveRecord::Migration[8.1]
  def change
    # The promotion the shopper picked for this line, when more than one could
    # apply to it. A column on the line rather than a row somewhere: it is a
    # line's own state like `selected`, and the discount rows the engine writes
    # are rebuilt on every recalculation
    # (docs/plans/6.1-store-api-miniprogram-gaps.md).
    add_column :spree_line_items, :chosen_promotion_id, :bigint
  end
end
