module Spree
  module PointProducts
    # A good that is shipped: the row points at the variant a redemption puts
    # on an ordinary order, which is where the stock and the fulfilment live.
    class Good < Spree::PointProduct
      belongs_to :variant, class_name: 'Spree::Variant', optional: true

      validates :variant_id, presence: true
    end
  end
end
