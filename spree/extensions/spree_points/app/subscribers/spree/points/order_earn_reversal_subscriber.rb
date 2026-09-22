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
        return if order.nil? || order.total.to_d.zero?

        reverse(order: order, fraction: return_record.refund_total.to_d / order.total.to_d,
                key: "return:#{return_record.id}")
      end

      def reverse(order:, fraction:, key:)
        attribution = Attribution.for(order)

        Spree::PointAccount::KINDS.each do |kind|
          account = Spree::PointAccount.find_by(store: order.store, customer: order.customer, kind: kind)
          next if account.nil?

          earn = Spree::LedgerEntry.find_by(account: account, idempotency_key: "order:#{order.id}:#{kind}")
          next if earn.nil?

          amount = clawback_for(earn, fraction, account)
          next unless amount.positive?

          Spree::Points::Ledger.debit!(account: account, amount: amount, reason: 'consume_return',
                                       source: order, idempotency_key: "#{key}:#{kind}", reverses: earn,
                                       seller: attribution[:seller], order: order)
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

        wanted = (earn.amount.to_d * fraction).floor - already
        return 0 unless wanted.positive?

        [wanted, outstanding, account.balance.to_d].min.to_i
      end
    end
  end
end
