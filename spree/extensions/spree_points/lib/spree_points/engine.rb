require 'rails/engine'

module SpreePoints
  class Engine < Rails::Engine
    engine_name 'spree_points'

    # Registered after initialization because core assigns the registry in its
    # own initializer, and engine callbacks run in load order.
    config.after_initialize do
      Spree.grant_kinds << Spree::Points::Lot
    end
  end
end
