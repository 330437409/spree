module Spree
  module FlashSales
    # The order carries the tickets that priced it — each seckill discount names
    # the ticket it was written from — so settling is read off the order rather
    # than guessed from who happens to be holding something.
    class SettleTicketsSubscriber < Spree::Subscriber
      subscribes_to 'order.completed'

      def handle(event)
        order = Spree::Order.find_by_prefix_id(event.payload['id'])
        return if order.nil?

        ticket_ids_for(order).each do |ticket_id|
          Spree::FlashSaleTicket.holding.find_by_prefix_id(ticket_id)&.settle!
        end
      end

      private

      def ticket_ids_for(order)
        order.discounts.manual.filter_map { |discount| discount.metadata&.fetch('flash_sale_ticket_id', nil) }.uniq
      end
    end
  end
end
