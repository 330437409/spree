# frozen_string_literal: true

# The routing endpoints, wired through Spree's extension hook so they are served
# under /api/v3/store/ without touching any core routes file. The controllers
# inherit the Store API's base, so publishable-key auth, the guest gate and the
# error shape behave exactly like core resources.
#
# They live here rather than in lib/ because this is the file Rails watches and
# re-loads: a routes reload re-draws Spree's engine routes, and a block
# registered once at boot from lib/ is not registered again, so every one of
# these endpoints would vanish from a running development server until it
# restarted.
Spree::Core::Engine.add_routes do
  namespace :api, defaults: { format: 'json' } do
    namespace :v3 do
      namespace :store do
        get 'location/resolve_seller', to: 'location/resolve_seller#show'
        get 'location/coverage', to: 'location/coverage#show'
        get 'service_areas/taken', to: 'service_areas/taken#show'

        # The sites a customer can shop at: where there are sites at all, and the
        # cities they are in. `sites/cities` is declared first so the collection
        # read does not swallow it.
        get 'sites/cities', to: 'sites/cities#index'
        resources :sites, only: [:index]

        # The record of the site a request belongs to — a singleton, because
        # which site it is comes from the request's own scope rather than a path
        # segment (see the seller resolution concern) — and where it delivers.
        resource :site, only: [:show]
        get 'site/coverage', to: 'site/coverage#show'
      end
    end
  end
end
