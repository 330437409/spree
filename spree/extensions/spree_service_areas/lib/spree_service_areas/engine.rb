require 'rails/engine'

module SpreeServiceAreas
  class Engine < Rails::Engine
    engine_name 'spree_service_areas'

    # The settings a store chooses its reverse geocoding with. They are added to
    # the model rather than through a migration, because a preference travels in
    # the store's own preferences column and a setting costs no schema — and
    # this runs after initialization so the class it decorates is loadable.
    config.after_initialize do
      Spree::Store.class_eval do
        preference :reverse_geocode_provider, :string, default: 'tencent'
        # What is tried when the provider above fails. Nothing answers until a
        # second vendor is wired, which is a state the resolution already
        # handles — and what the setting exists for.
        preference :reverse_geocode_fallback_provider, :string
        preference :reverse_geocode_tencent_key, :string
        preference :reverse_geocode_ttl_days, :integer, default: 30
      end
    end
  end
end
