module Spree
  module Points
    # An order the customer actually paid earns both balances, once.
    #
    # `order.paid` rather than placement: the plan's inputs are all measured on
    # the order the customer paid, and a cart that is submitted and never
    # settled has earned nothing. One key per order *and balance*, so a payment
    # that settles in two steps — or an event delivered twice — is one earn,
    # while the grant row's own uniqueness, which is per store and kind, is not
    # asked for one key twice.
    class OrderPaidSubscriber < Spree::Subscriber
      subscribes_to 'order.paid'

      def handle(event)
        order = Spree::Order.find_by_prefix_id(event.payload['id'])
        return if order.nil?

        earned = Earning.call(order: order).value
        return unless earned.positive?

        attribution = Attribution.for(order)

        Spree::PointAccount::KINDS.each do |kind|
          account = Spree::PointAccount.for(store: order.store, customer: order.customer, kind: kind)

          Spree::Points::Ledger.credit!(account: account, amount: earned, reason: 'consume',
                                        idempotency_key: "#{earn_key(order)}:#{kind}", source: order,
                                        expires_at: expiry_for(account), seller: attribution[:seller],
                                        order: order)
        end
      end

      private

      # What the reversal looks up when it is asked to take the earn back.
      #
      # @return [String]
      def earn_key(order)
        "order:#{order.id}"
      end

      # Points lapse, 成长值 does not: the window is the store's, and the credit
      # service refuses a date on the balance that never lapses.
      def expiry_for(account)
        return nil unless account.points?

        account.store.preferred_points_validity_days.to_i.days.from_now
      end
    end
  end
end
