require 'rails/engine'

module SpreeServiceAreas
  class Engine < Rails::Engine
    engine_name 'spree_service_areas'

    # The settings this gem reads — `preferred_reverse_geocode_provider` and its
    # siblings — are declared on `Spree::Store` in core rather than here: a gem
    # may not add an attribute to a core class, which is the same rule that put
    # the binding columns and the coordinate normalizer there.
  end
end
