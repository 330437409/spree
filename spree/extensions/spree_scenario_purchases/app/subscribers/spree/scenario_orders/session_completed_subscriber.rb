module Spree
  module ScenarioOrders
    # A session settled, so the purchase behind it is paid for.
    #
    # This is the one place a completion is noticed, whichever route delivered
    # it — the gateway's webhook or the customer's own confirm call — so the two
    # cannot drift apart.
    class SessionCompletedSubscriber < Spree::Subscriber
      subscribes_to 'payment_session.completed'

      def handle(event)
        session = Spree::PaymentSession.find_by_prefix_id(event.payload['id'])
        scenario_order = session&.scenario_order
        return if scenario_order.nil?

        Spree::ScenarioOrders::Settle.call(scenario_order: scenario_order)
      end
    end
  end
end
