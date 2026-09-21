module Spree
  module Recommendations
    # What a shopper might also want, read from what is already in their
    # basket: the categories the cart's goods are in, ranked by what sells.
    #
    # Asked through the store's search provider rather than by a query of its
    # own, so a store with an index answers from it and a store without one
    # answers from the database — the provider decides, and the catalogue the
    # caller passes decides what may be answered at all
    # (docs/plans/6.1-store-api-miniprogram-gaps.md).
    class ForCart
      prepend Spree::ServiceModule::Base

      # @param cart [Spree::Cart] the basket the shelf is about
      # @param scope [ActiveRecord::Relation] the catalogue this read may
      #   answer from — the storefront's own, so a recommendation is never a
      #   way to see something the catalogue would not show
      # @param limit [Integer] how many goods to offer
      # @return [Spree::ServiceModule::Result] value is an array of products,
      #   in the provider's order
      def call(cart:, scope:, limit: 12)
        category_ids = category_ids_for(cart)
        return success([]) if category_ids.empty?

        result = Spree.search_provider.constantize.new(cart.store).search_and_filter(
          scope: without_the_basket(scope, cart),
          filters: { 'in_categories' => category_ids },
          sort: 'best_selling',
          limit: limit
        )

        success(result.products)
      end

      private

      # The categories the cart's goods are in. A basket of one kind of thing
      # recommends more of that kind; it is the client's own shelf title —
      # "based on the goods in your order".
      #
      # @return [Array<String>] prefixed category ids
      def category_ids_for(cart)
        product_ids = cart.line_items.joins(:variant).select(Spree::Variant.arel_table[:product_id])

        Spree::ProductCategory.
          where(product_id: product_ids).
          distinct.
          pluck(:category_id).
          map { |id| Spree::Category.prefixed_id_for(id) }
      end

      # What the shopper already has in front of them is not a recommendation.
      # Narrowed on the scope rather than asked for as a search filter: a
      # provider filter widens a search over the index, and this has to hold
      # for the database provider too, which has no such filter.
      #
      # @return [ActiveRecord::Relation]
      def without_the_basket(scope, cart)
        scope.where.not(id: basket_product_ids(cart))
      end

      # @return [ActiveRecord::Relation] the products the basket holds
      def basket_product_ids(cart)
        Spree::Variant.where(id: cart.line_items.select(:variant_id)).select(:product_id)
      end
    end
  end
end
