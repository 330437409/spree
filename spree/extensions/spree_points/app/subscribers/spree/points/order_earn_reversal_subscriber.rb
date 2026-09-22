module Spree
  module Points
    # What an order is asked to give back: everything when it is called off,
    # and the return's share of it when goods come back.
    #
    # A reversal is a row that points at the earn — 消费退回, the reason the
    # client already names — never an edit, which is what keeps the history the
    # customer reads true to what happened.
    class OrderEarnReversalSubscriber < Spree::Subscriber
      subscribes_to 'order.canceled', 'return.refunded'

      on 'order.canceled', :reverse_what_the_order_earned
      on 'return.refunded', :reverse_the_returns_share

      private

      def reverse_what_the_order_earned(event)
        order = Spree::Order.find_by_prefix_id(event.payload['id'])
        return if order.nil?

        reverse(order: order, fraction: 1.to_d, key: "cancel:#{order.id}")
      end

      def reverse_the_returns_share(event)
        return_record = Spree::Return.find_by_prefix_id(event.payload['id'])
        order = return_record&.order
        return if order.nil? || order.item_total.to_d.zero?

        # The goods' own value over the goods' own value in the order: a return
        # that gives every good back gives the whole earn back, where dividing
        # by the order's total — which carries tax and delivery — would leave
        # the store holding that slice.
        reverse(order: order, fraction: return_record.refund_total.to_d / order.item_total.to_d,
                key: "return:#{return_record.id}")
      end

      def reverse(order:, fraction:, key:)
        Spree::PointAccount::KINDS.each do |kind|
          account = Spree::PointAccount.find_by(store: order.store, customer: order.customer, kind: kind)
          next if account.nil?

          earn = Spree::LedgerEntry.find_by(account: account,
                                            idempotency_key: Spree::Points::Ledger.earn_key(order, kind))

          # Both subscribers are async, so a refund hard on the heels of a
          # payment can arrive before the earn it is meant to reverse. That is
          # worth a line in the log rather than a silent skip: the job will not
          # be retried, and the customer keeps points for goods they returned.
          if earn.nil?
            Rails.logger.warn("points: no earn to reverse for order #{order.number} (#{kind})")
            next
          end

          amount = clawback_for(earn, fraction, account)
          next unless amount.positive?

          Spree::Points::Ledger.debit!(account: account, amount: amount, reason: 'consume_return',
                                       source: order, idempotency_key: "#{key}:#{kind}", reverses: earn,
                                       seller: order.seller, order: order)
        end
      end

      # What is left to take back, held to three ceilings: the share this event
      # asks for, what the earn has not already given back, and what the balance
      # actually holds — points a customer has spent cannot be clawed back
      # without a negative balance, which this ledger has no way to write.
      #
      # @return [Integer]
      def clawback_for(earn, fraction, account)
        already = Spree::LedgerEntry.where(reverses_entry: earn).sum(:amount).to_d.abs
        outstanding = earn.amount.to_d - already
        return 0 unless outstanding.positive?

        # This event's own share, not what is left of it after earlier ones:
        # two separate returns of the same order each ask for their own share,
        # and the ceilings below are what stop the pair from exceeding the
        # earn — subtracting here as well would let the second return claw
        # back nothing at all.
        wanted = (earn.amount.to_d * fraction).floor
        return 0 unless wanted.positive?

        [wanted, outstanding, account.balance.to_d].min.to_i
      end
    end
  end
end
