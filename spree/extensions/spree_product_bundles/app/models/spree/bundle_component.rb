module Spree
  # One variant in a bundle, and how many of it the set contains.
  #
  # It holds no price and no stock of its own: both are read from the variant,
  # which is what keeps a bundle's price and availability honest when either
  # moves upstream.
  class BundleComponent < Spree.base_class
    belongs_to :bundle, class_name: 'Spree::ProductBundle', inverse_of: :components
    belongs_to :variant, class_name: 'Spree::Variant'

    validates :quantity, numericality: { greater_than: 0 }
    validates :variant_id, uniqueness: { scope: [:bundle_id, *spree_base_uniqueness_scope] }

    # What this line of the set costs at the variant's current price, in the
    # currency the request is in.
    # @param currency [String, nil]
    # @return [BigDecimal]
    def goods_amount(currency = nil)
      currency ||= Spree::Current.currency || bundle&.store&.default_currency
      (variant&.amount_in(currency) || 0).to_d * quantity.to_i
    end

    # What the shelf holds of this component, from core's own arithmetic —
    # reservations subtracted, backorders honoured, external providers included.
    # @param stock_location [Spree::StockLocation, nil]
    # @return [Integer]
    def available_units(stock_location: nil)
      return 0 if variant.nil?

      Spree::Stock::Quantifier.new(variant, stock_location).total_on_hand.to_i
    end
  end
end
