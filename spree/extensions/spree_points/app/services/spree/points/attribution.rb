module Spree
  module Points
    # Who a movement belongs to, for the two columns the shared ledger row
    # carries beside whatever caused it.
    #
    # The order is always the one in hand. The seller is the shop the order was
    # placed with — the mini program's cart is per site, so an order has one —
    # and nil where the order's goods come from none or from several, which is
    # what a movement the balance cannot attribute should say rather than
    # guessing.
    class Attribution
      # @param order [Spree::Order]
      # @return [Hash] the ledger's own keywords
      def self.for(order)
        { order: order, seller: seller_for(order) }
      end

      # @return [Spree::Seller, nil]
      def self.seller_for(order)
        sellers = order.line_items.joins(variant: :seller).distinct.pluck('spree_variants.seller_id')
        return nil unless sellers.one?

        Spree::Seller.find_by(id: sellers.first)
      end
    end
  end
end
