module Spree
  # What a basket of goods would cost, before there is a cart to put it in.
  #
  # The product page asks this on every visit: a set of variants and quantities,
  # priced in the context the request already carries — the channel it resolved,
  # its currency, the country the buyer is taxed in, and the customer when there
  # is one. It reaches its price through the same provider the cart prices a line
  # through, and restates it for the destination the same way the cart does, so
  # what it answers is what the cart would write: a second calculation is how two
  # answers to one question start.
  #
  # Availability is the buyer-facing shelf — on hand, net of what live checkouts
  # hold — and never a claim on it: nothing here reserves anything.
  class PricePreview
    prepend Spree::ServiceModule::Base

    # @param items [Enumerable<Hash>] `{ variant:, quantity: }`, already resolved
    #   and scoped by the caller
    # @param currency [String, nil] defaults to the request's currency
    # @param customer [Object, nil] the shopper whose price lists apply
    # @param context [Hash] what a registered source needs to price a line — an
    #   activity's id, a ticket's — passed through untouched
    # @param stock_location [Spree::StockLocation, nil] the warehouse the request
    #   is asking about, when it is asking about one: a line then answers that
    #   shop's shelf as well as the goods' own availability
    # @return [Spree::ServiceModule::Result] value is a {Spree::PricePreview::Result}
    def call(items:, currency: nil, customer: nil, context: {}, stock_location: nil)
      currency ||= Spree::Current.currency
      @stock_location = stock_location

      rows = Array(items).filter_map { |item| row_for(item, currency, customer, context) }

      success(Result.new(currency: currency, rows: rows))
    end

    private

    def row_for(item, currency, customer, context)
      variant = item[:variant] || item['variant']
      return nil if variant.blank?

      quantity = (item[:quantity] || item['quantity'] || 1).to_i
      pricing = context_for(variant, currency, quantity, customer)
      price = variant.price_for(pricing)
      catalogue_amount = amount_for(price)

      source = source_answer(variant: variant, quantity: quantity, customer: customer, context: context)

      Row.new(
        variant: variant,
        quantity: quantity,
        price: price,
        unit_amount: source ? source[:amount] : catalogue_amount,
        # A source that prices a line below the catalogue shows what it was
        # priced against, which is the strike-through the page renders.
        compare_at_amount: source ? catalogue_amount : compare_at_amount(variant, price, currency),
        source: source&.fetch(:label, nil),
        flags: source&.fetch(:flags, nil) || {},
        in_stock: variant.in_stock?,
        backorderable: variant.backorderable?,
        purchasable: variant.purchasable?,
        available_quantity: Spree::Stock::Quantifier.new(variant).total_on_hand,
        # What the named shop itself has on the shelf. Nil when the request is
        # not about one shop, which is every read that is not an area page.
        stock_location_quantity: stock_location_quantity_for(variant),
        # Kept as the record rather than its id, so a caller can say which list
        # priced the line and which source answered.
        price_list_id: price&.price_list&.prefixed_id,
        # How long the price it answered holds: a source's own window when one
        # priced the line, otherwise the list's. Nil when nothing time-boxes it,
        # which is the ordinary catalogue price.
        price_ends_at: source&.fetch(:ends_at, nil) || price&.price_list&.ends_at
      ).tap do |row|
        row.total = row.unit_amount && row.unit_amount * quantity
      end
    end

    # The first registered source that has something to say about this line
    # prices it — one answer, so two sources cannot each take a bite.
    # @return [Hash, nil]
    def source_answer(variant:, quantity:, customer:, context:)
      Spree.price_preview_sources.each do |source|
        answer = source.call(variant: variant, quantity: quantity, customer: customer, context: context)
        return answer if answer.present?
      end

      nil
    end

    def stock_location_quantity_for(variant)
      return nil if @stock_location.nil?

      Spree::Stock::Quantifier.new(variant, @stock_location).total_on_hand
    end

    def context_for(variant, currency, quantity, customer)
      Spree::Pricing::Context.new(variant: variant, currency: currency, quantity: quantity, user: customer)
    end

    # What the cart would write on the line. The catalogue price is a net one
    # for most stores and a buyer outside the store's own country has to have
    # their own rate put on it — the cart restates for its destination, so this
    # restates for the request's.
    # @return [Numeric, nil]
    def amount_for(price)
      return nil if price.nil?

      price.price_including_vat_for(vat_inputs)
    end

    # The price to strike through, and only when it is not the one being charged
    # — the same rule the variant read shows: a list's price with the base price
    # beside it, restated the same way so the two can be read together.
    def compare_at_amount(variant, price, currency)
      base = variant.price_in(currency)
      return nil if base.blank? || price.blank? || base.id == price.id

      base.price_including_vat_for(vat_inputs)
    end

    def vat_inputs
      { address: nil, country: Spree::Current.tax_country, market: Spree::Current.market }
    end
  end
end
