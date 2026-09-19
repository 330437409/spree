module Spree
  module PriceContexts
    # Which sellers hold an offer for a product — the read a client makes before
    # it rebinds its global site to one of them.
    #
    # An offer is a variant, and a variant's seller is its product's when the
    # product belongs to a seller at all (`Spree::Variant#resolved_seller`, the
    # same rule the buy box ranks by), so a seller-owned listing answers with
    # its owner and a shared listing with the sellers of its variants.
    #
    # It asks only whether a seller is selling today — the `sellable` gate core
    # already applies to a catalogue read — and deliberately not whether one
    # serves the customer's location: that is the routing plan's question,
    # answered by `GET /api/v3/store/location/resolve_seller`, and a coverage
    # test here would be a second eligibility mechanism disagreeing with it
    # (docs/plans/6.1-seller-scoped-pricing.md).
    class ProductSellers
      # @param product [Spree::Product]
      # @return [ActiveRecord::Relation<Spree::Seller>] the store's sellable
      #   sellers holding an offer for the product, or none
      def self.call(product:)
        new(product: product).call
      end

      def initialize(product:)
        @product = product
      end

      def call
        ids = seller_ids
        return Spree::Seller.none if ids.empty?

        Spree::Seller.for_store(@product.store).sellable.where(id: ids).order(:id)
      end

      private

      def seller_ids
        return [@product.seller_id] if @product.seller_id.present?

        # `reorder(nil)` because the variants relation carries its own ordering
        # by position, and both PostgreSQL and MySQL refuse a DISTINCT whose
        # ORDER BY expression is not in the select list — which a pluck of one
        # column is. The order is not wanted here in any case.
        @product.variants.where.not(seller_id: nil).reorder(nil).distinct.pluck(:seller_id)
      end
    end
  end
end
