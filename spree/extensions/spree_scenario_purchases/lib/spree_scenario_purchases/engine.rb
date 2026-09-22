require 'rails/engine'

module SpreeScenarioPurchases
  class Engine < Rails::Engine
    engine_name 'spree_scenario_purchases'

    # Registered after initialization because core assigns the registries in its
    # own initializers, and engine callbacks run in load order.
    config.after_initialize do
      # A purchase that is not an order is still paid through a session, so the
      # frame registers the shape core's payment rows read their owner through.
      Spree::Payment.register_owner_association(:scenario_order)
      Spree::PaymentSession.register_owner_association(:scenario_order)

      subscriber = Spree::ScenarioOrders::SessionCompletedSubscriber
      Spree.subscribers << subscriber unless Spree.subscribers.include?(subscriber)
    end
  end
end
