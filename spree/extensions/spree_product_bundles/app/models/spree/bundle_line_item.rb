module Spree
  # The grouping key a bundle's cart lines share: one row per component line,
  # written when the bundle is added and removed when the group goes.
  #
  # A gem-owned join row rather than a column on `spree_line_items` — a
  # migration this gem ships is one upstream never has to reconcile, where a new
  # column on a core table is permanent (docs/plans/6.1-product-bundles.md).
  class BundleLineItem < Spree.base_class
    belongs_to :bundle, class_name: 'Spree::ProductBundle', inverse_of: :bundle_line_items
    belongs_to :line_item, class_name: 'Spree::LineItem'

    validates :line_item_id, uniqueness: true
  end
end
