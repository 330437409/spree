# frozen_string_literal: true

# The routing endpoint, wired through Spree's extension hook so it is served at
# /api/v3/store/location/resolve_seller without touching any core routes file.
# The controller inherits the Store API's base, so publishable-key auth, the
# guest gate and the error shape behave exactly like core resources.
#
# Required from lib/spree_service_areas.rb, early, so the block is registered
# before Spree draws its routes.
Spree::Core::Engine.add_routes do
  namespace :api, defaults: { format: 'json' } do
    namespace :v3 do
      namespace :store do
        get 'location/resolve_seller', to: 'location/resolve_seller#show'

        # The record of the site a request belongs to — a singleton, because
        # which site it is comes from the request's own scope rather than a path
        # segment (see the seller resolution concern).
        resource :site, only: [:show]
      end
    end
  end
end
