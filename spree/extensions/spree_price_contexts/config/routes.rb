# frozen_string_literal: true

# The sellers read, wired through Spree's extension hook so it is served at
# /api/v3/store/products/:id/sellers without touching any core routes file. The
# controller inherits the Store API's base, so publishable-key auth, the guest
# gate and the error shape behave exactly like core resources.
#
# It lives here rather than in lib/ because this is the file Rails watches and
# re-loads: a routes reload re-draws Spree's engine routes, and a block
# registered once at boot from lib/ is not registered again, so the endpoint
# would vanish from a running development server until it restarted.
Spree::Core::Engine.add_routes do
  namespace :api, defaults: { format: 'json' } do
    namespace :v3 do
      namespace :store do
        resources :products, only: [] do
          resources :sellers, only: [:index], controller: 'products/sellers'
        end
      end
    end
  end
end
