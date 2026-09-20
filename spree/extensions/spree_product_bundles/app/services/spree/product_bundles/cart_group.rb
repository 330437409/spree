module Spree
  module ProductBundles
    # A bundle as one cart holds it: the set, and the lines it was added as.
    #
    # The lines are ordinary ones — the cart holds the components, never the
    # bundle — so this is the shape that gathers them back into the card a
    # storefront renders, and every figure comes from the lines themselves
    # rather than from a second computation of the price.
    class CartGroup
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :bundle
      attribute :line_items, default: -> { [] }

      delegate :title, :slug, to: :bundle

      # What the lines cost before the set's own saving.
      # @return [BigDecimal]
      def goods_price
        line_items.sum(BigDecimal(0)) { |line_item| line_item.amount.to_d }
      end

      # What the gem took off this set, read back from the discount rows it
      # wrote: they are what the customer is charged against, so a group renders
      # what it was actually given rather than what the rule would give now.
      # @return [BigDecimal]
      def saving
        -line_items.sum(BigDecimal(0)) { |line_item| discount_amount_for(line_item) }
      end

      # @return [BigDecimal]
      def price
        goods_price - saving
      end

      # How many whole sets the lines hold: the smallest of what each line
      # carries in its component's units.
      # @return [Integer]
      def quantity
        quantities = bundle.components.map do |component|
          line = line_items.find { |line_item| line_item.variant_id == component.variant_id }
          line.nil? ? 0 : line.quantity / component.quantity
        end

        quantities.min || 0
      end

      # How many more the shelf could fill, which is the number the client
      # compares its own threshold against.
      # @return [Integer]
      def available
        bundle.available_bundles
      end

      private

      # Only this gem's own rows, matched on the code prefix every one of them
      # carries — a merchant's own manual adjustment on the same line is not
      # the set's saving.
      def discount_amount_for(line_item)
        discounts = Spree::Discount.arel_table
        line_item.owner.discounts.
          where(line_item_id: line_item.id).
          where(discounts[:code].matches("#{ApplySaving::CODE_PREFIX}%")).
          sum(:amount).to_d
      end
    end
  end
end
