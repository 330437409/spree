require 'rails/engine'

module SpreeServiceAreas
  class Engine < Rails::Engine
    engine_name 'spree_service_areas'

    # The settings this gem reads — `preferred_reverse_geocode_provider` and its
    # siblings — are declared on `Spree::Store` in core rather than here: a gem
    # may not add an attribute to a core class, which is the same rule that put
    # the binding columns and the coordinate normalizer there.
    #
    # Adding a *kind* to a core registry is the other half of that rule: core
    # owns the checklist, this deployment contributes one question to it.
    # Registered after initialization because core assigns the registry in its
    # own, and engine callbacks run in load order.
    config.after_initialize do
      Spree.seller_requirements << SpreeServiceAreas::ServiceAreaRequirement
    end
  end
end
