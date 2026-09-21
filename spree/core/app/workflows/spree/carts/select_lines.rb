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
          step :move_stock_hold if changed.positive?
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
        moved = line_items.where(selected: !selected)
        # Read before the update: a statement leaves no records behind, and the
        # lines it moved are the ones whose stock hold follows them.
        @moved_line_item_ids = moved.ids
        @changed = moved.update_all(selected: selected, updated_at: Time.current)
      end

      # A tick decides whether a line is being bought, and the hold on its stock
      # follows: an unticked line gives its stock back at once rather than
      # holding it until the reservation expires, and a line ticked back takes a
      # hold again (docs/plans/fork-decisions.md, 2026-09-20, the money
      # scoping).
      def move_stock_hold
        if selected
          # Ticking can outrun the shelf, and a line that cannot be held is one
          # checkout refuses — not a reason to undo the tick. The hold is what
          # the shopper's place rests on, so it is taken now rather than at the
          # next write to the cart.
          Spree::StockReservations::Reserve.call(cart: cart)
        else
          Spree::StockReservation.withdraw(cart.stock_reservations.where(line_item_id: @moved_line_item_ids))
        end
      end
    end
  end
end
