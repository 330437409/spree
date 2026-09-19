module Spree
  # What a basket of goods would cost, before there is a cart to put it in.
  #
  # The product page asks this on every visit: a set of variants and quantities,
  # priced in the context the request already carries — the channel it resolved,
  # its currency, the country the buyer is taxed in, and the customer when there
  # is one. It reaches its price through the same provider the cart prices a line
  # through, because a second calculation is how two answers to one question
  # start.
  #
  # Availability is the shelf's own — what is on hand, net of what is already
  # allocated — and never a claim on it: nothing here reserves anything.
  class PricePreview
    prepend Spree::ServiceModule::Base

    # @param items [Enumerable<Hash>] `{ variant:, quantity: }`, already resolved
    #   and scoped by the caller
    # @param currency [String, nil] defaults to the request's currency
    # @param customer [Object, nil] the shopper whose price lists apply
    # @return [Spree::ServiceModule::Result] value is a {Spree::PricePreview::Result}
    def call(items:, currency: nil, customer: nil)
      currency ||= Spree::Current.currency

      rows = Array(items).filter_map { |item| row_for(item, currency, customer) }

      success(Result.new(currency: currency, rows: rows))
    end

    private

    def row_for(item, currency, customer)
      variant = item[:variant] || item['variant']
      return nil if variant.blank?

      quantity = (item[:quantity] || item['quantity'] || 1).to_i
      price = variant.price_for(context_for(variant, currency, quantity, customer))

      Row.new(
        variant: variant,
        quantity: quantity,
        price: price,
        unit_amount: price&.amount,
        compare_at_amount: compare_at_amount(variant, price, currency),
        total: (price&.amount || 0) * quantity,
        in_stock: variant.in_stock?,
        backorderable: variant.backorderable?,
        purchasable: variant.purchasable?,
        available_quantity: Spree::Stock::Quantifier.new(variant).available_stock
      )
    end

    def context_for(variant, currency, quantity, customer)
      Spree::Pricing::Context.new(variant: variant, currency: currency, quantity: quantity, user: customer)
    end

    # The price to strike through, and only when it is not the one being charged
    # — the same rule the variant read shows: a list's price with the base price
    # beside it.
    def compare_at_amount(variant, price, currency)
      base = variant.price_in(currency)
      return nil if base.blank? || price.blank? || base.id == price.id

      base.amount
    end
  end
end
