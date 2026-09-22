require 'rails/engine'

module SpreeScenarioPurchases
  class Engine < Rails::Engine
    engine_name 'spree_scenario_purchases'

    # `to_prepare` rather than `after_initialize`, because one of these writes to
    # a class rather than to a registry: a reload in development redefines
    # `Spree::PaymentSession` and the association declared at boot goes with it,
    # where an array on a module would have survived. Both calls are idempotent,
    # so running them again after every reload is the point.
    config.to_prepare do
      # A purchase that is not an order is still paid through a session, so the
      # frame registers the shape core's payment rows read their owner through.
      Spree::Payment.register_owner_association(:scenario_order)
      Spree::PaymentSession.register_owner_association(:scenario_order)

      subscriber = Spree::ScenarioOrders::SessionCompletedSubscriber
      Spree.subscribers << subscriber unless Spree.subscribers.include?(subscriber)
    end
  end
end
