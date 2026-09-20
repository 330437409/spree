module Spree
  module Carts
    # Writes the shopper's ticks over a set of a cart's lines.
    #
    # The selection is an input to the cart's money rather than a filter over
    # it, so a tick moves the subtotal, the promotion rows, the tax rows and
    # the delivery proposals together — and the cart therefore recalculates
    # once for the whole set, which is why this is a workflow rather than a
    # loop over the lines
    # (docs/plans/6.1-store-api-miniprogram-gaps.md).
    class SelectLines < Spree::Workflow
      # @param cart [Spree::Cart]
      # @param line_items [ActiveRecord::Relation] the lines to write, already
      #   scoped to this cart by the caller
      # @param selected [Boolean] what to write on them
      # @return [Spree::ServiceModule::Result] value is the cart
      def perform(cart:, line_items:, selected:)
        super
        @changed = 0

        ApplicationRecord.transaction do
          step :write_selection
          # Only when a tick actually moved: a client re-sending the same set —
          # select-all over an already-ticked cart — must not pay for the money
          # math.
          step :recalculate, with: -> { Spree.cart_recalculate_workflow } if changed.positive?
        end

        success(cart)
      end

      # How many lines the write moved.
      # @return [Integer]
      attr_reader :changed

      private

      def write_selection
        @changed = line_items.
                   where(selected: !selected).
                   update_all(selected: selected, updated_at: Time.current)
      end
    end
  end
end
