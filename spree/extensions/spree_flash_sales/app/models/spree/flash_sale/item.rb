module Spree
  class FlashSale
    # Which offer an activity sells, at what price, and its own share of the
    # pool when the activity gives one item a smaller one than the rest.
    class Item < Spree.base_class
      belongs_to :flash_sale, class_name: 'Spree::FlashSale', inverse_of: :items
      belongs_to :variant, class_name: 'Spree::Variant'
      has_many :pools, class_name: 'Spree::FlashSale::Pool', dependent: :destroy, inverse_of: :item

      validates :variant_id, uniqueness: { scope: [:flash_sale_id, *spree_base_uniqueness_scope] }
      validates :sale_amount, numericality: { greater_than_or_equal_to: 0 }
      validates :pool, numericality: { greater_than_or_equal_to: 0 }

      scope :ordered, -> { order(:position) }
    end
  end
end
