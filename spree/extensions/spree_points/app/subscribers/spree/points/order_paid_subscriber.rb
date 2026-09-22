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
        # An order whose customer is gone — a deleted account, a guest — has
        # nobody to owe, and a balance row cannot be written for nobody.
        return if order.nil? || order.customer.nil?

        earned = Earning.call(order: order).value
        return unless earned.positive?

        Spree::PointAccount::KINDS.each do |kind|
          account = Spree::PointAccount.for(store: order.store, customer: order.customer, kind: kind)

          result = Spree::Points::Ledger.credit!(account: account, amount: earned, reason: 'consume',
                                                 idempotency_key: Spree::Points::Ledger.earn_key(order, kind),
                                                 source: order, expires_at: expiry_for(account, order.store),
                                                 seller: order.seller, order: order)

          # A refusal is not a retry: the ledger answers the row it already has,
          # and refuses a key reused for a *different* movement — an order that
          # changed between two `order.paid` events recomputes a different
          # amount, and the customer keeps whatever the first one wrote.
          if result.failure?
            Rails.logger.warn("points: order #{order.number} (#{kind}) was not credited: #{result.error}")
          end
        end
      end

      private

      # Points lapse, 成长值 does not: the window is the store's, and the credit
      # service refuses a date on the balance that never lapses.
      # Points lapse, 成长值 does not: the window is the store's, and a window
      # of zero is no window at all rather than a lot that is expired the moment
      # it is minted.
      def expiry_for(account, store)
        return nil unless account.points?

        days = store.preferred_points_validity_days.to_i
        days.positive? ? days.days.from_now : nil
      end
    end
  end
end
