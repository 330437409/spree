module Spree
  module FlashSales
    # Writes the activity's price onto a line: the difference between what the
    # catalogue asks and what the activity says, as a `manual`-kind discount
    # naming both the activity and the ticket it came from.
    #
    # A discount rather than a promotion action, because the engine reconciles
    # its own rows destructively and winner-only, and a seckill competes with
    # nothing — the activity's price is the price. Naming the ticket is also what
    # makes a seckill line's refund recomputable.
    class ApplyTicketPrice
      prepend Spree::ServiceModule::Base

      # @param ticket [Spree::FlashSaleTicket]
      # @param line_item [Spree::LineItem]
      # @return [Spree::ServiceModule::Result] value is the discount row, or nil
      #   when the catalogue already charges the activity's price
      def call(ticket:, line_item:)
        @ticket = ticket
        @line_item = line_item
        @flash_sale = ticket.flash_sale

        item = @flash_sale.items.find_by(variant: line_item.variant)
        return failure(nil, Spree.t('flash_sales.refusals.not_in_activity')) if item.nil?

        difference = difference_for(item)
        return success(nil) unless difference.positive?

        row = write_discount(difference)
        @line_item.owner.recalculate_totals! if @line_item.owner.respond_to?(:recalculate_totals!)

        success(row)
      end

      private

      # What the activity takes off, in the line's own units. Never more than
      # the line costs, so the row cannot drive a line below zero.
      def difference_for(item)
        catalogue = @line_item.price.to_d
        sale = item.sale_amount.to_d
        return 0.to_d unless catalogue > sale

        (catalogue - sale) * @line_item.quantity
      end

      # One row per ticket per line, found by its own code so re-pricing the line
      # updates what is there rather than stacking a second discount on it.
      def write_discount(difference)
        row = owner.discounts.find_or_initialize_by(code: code)
        row.assign_attributes(
          line_item: @line_item,
          kind: 'manual',
          label: Spree.t('flash_sales.discount_label', title: @flash_sale.title),
          amount: -difference,
          value: difference,
          value_type: 'flat',
          metadata: {
            'flash_sale_id' => @flash_sale.prefixed_id,
            'flash_sale_ticket_id' => @ticket.prefixed_id
          }
        )
        row.save!
        row
      end

      def owner
        @line_item.owner
      end

      def code
        "flash_sale:#{@ticket.prefixed_id}"
      end
    end
  end
end
