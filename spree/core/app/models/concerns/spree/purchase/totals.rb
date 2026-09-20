module Spree
  module Purchase
    # Money readers shared by Spree::Cart and Spree::Order. The raw
    # +outstanding_balance+ stays host-specific on purpose: an order nets
    # reimbursement payouts and inverts on cancellation, a cart is plain
    # total minus payments.
    module Totals
      # @return [Integer] total units across line items
      def quantity
        line_items.sum(:quantity)
      end

      # The units the shopper has ticked for checkout, which is what a cart's
      # own page renders beside the cart's total. A cart is completed from its
      # selected lines and nothing else, so this is the figure checkout is
      # about (docs/plans/6.1-store-api-miniprogram-gaps.md).
      # @return [Integer]
      def selected_quantity
        line_items.selected.sum(:quantity)
      end

      # The lines this record's money is computed over. An order's lines are
      # all its own — it was completed from ticked cart lines, so every line it
      # holds was ticked; a cart prices only what the shopper ticked and lets
      # the rest sit in the cart uncharged. Every money path reads this rather
      # than +line_items+ (docs/plans/6.1-store-api-miniprogram-gaps.md).
      # @return [ActiveRecord::Relation]
      def priced_line_items
        line_items
      end

      # The products this record's money is about, for the rules that ask
      # "does this purchase contain X" — a promotion whose trigger product is
      # sitting unticked in the cart must not fire on what the shopper is
      # actually buying.
      # @return [Array<String>]
      def priced_product_ids
        product_ids
      end

      # @return [BigDecimal]
      def amount
        priced_line_items.sum(BigDecimal('0'), &:amount)
      end

      # Re-sums what the customer has actually paid, and nothing else. A
      # payment settling moves only the payment side of the ledger — item
      # and delivery money is the totals workflow's business, and
      # re-deriving it here would overwrite figures a caller set
      # deliberately.
      #
      # Shared by Cart and Order: both carry payment_total, and payments
      # settle on a cart during checkout.
      #
      # @return [BigDecimal] the persisted payment_total
      def refresh_payment_total!
        # One atomic statement: the sum and the write have to be a single
        # step, or two handlers settling different payments interleave and
        # the older one writes its smaller total last, leaving the record
        # short-paid with no further event coming to correct it.
        #
        # Deliberately not with_lock, which refuses a record carrying
        # unsaved changes — callers legitimately hold dirty attributes while
        # a payment is destroyed (cart teardown, order merging), and this
        # must never disturb their in-memory state.
        settled = settled_payments_arel
        self.class.where(id: id).update_all(payment_total: settled)
        self.payment_total = self.class.where(id: id).pick(:payment_total)
      end

      # @return [Boolean]
      def outstanding_balance?
        outstanding_balance != 0
      end

      # Balance still to collect after applied store credit, never negative.
      #
      # @return [BigDecimal]
      def amount_due
        [outstanding_balance - total_applied_store_credit, 0].max
      end

      # @return [Boolean]
      def paid?
        total.positive? && payment_total >= total
      end

      # What has to be paid before this purchase can be placed and
      # dispatched — the whole total unless an arrangement collects only part
      # of it up front. See {Spree::Purchases::AmountDueAtCheckout}, which is
      # where a deposit or net terms would answer differently.
      #
      # @return [BigDecimal]
      def amount_due_at_checkout
        Spree.purchase_amount_due_at_checkout_service.new.call(purchase: self)
      end

      # Total fulfillment discount applied by promotions, as a positive amount.
      #
      # @return [BigDecimal]
      def fulfillment_discount
        discounts.for_fulfillments.sum(:amount) * -1
      end

      private

      # Completed payments less their refunds, as a scalar subquery so the
      # sum and the write are one statement.
      #
      # @return [Arel::Nodes::Grouping]
      def settled_payments_arel
        payments_table = Spree::Payment.arel_table
        refunds_table = Spree::Refund.arel_table

        settled = payments_table.project(payments_table[:id]).
                  where(payments_table[owner_foreign_key].eq(id)).
                  where(payments_table[:status].eq('completed'))

        captured = payments_table.project(payments_table[:amount].sum).
                   where(payments_table[owner_foreign_key].eq(id)).
                   where(payments_table[:status].eq('completed'))

        refunded = refunds_table.project(refunds_table[:amount].sum).
                   where(refunds_table[:payment_id].in(settled))

        Arel::Nodes::NamedFunction.new(
          'COALESCE',
          [
            Arel::Nodes::Subtraction.new(
              Arel::Nodes::NamedFunction.new('COALESCE', [Arel::Nodes::Grouping.new(captured), Arel.sql('0')]),
              Arel::Nodes::NamedFunction.new('COALESCE', [Arel::Nodes::Grouping.new(refunded), Arel.sql('0')])
            ),
            Arel.sql('0')
          ]
        )
      end

      # @return [Symbol] the column payments use to point at this record
      def owner_foreign_key
        is_a?(Spree::Cart) ? :cart_id : :order_id
      end
    end
  end
end
