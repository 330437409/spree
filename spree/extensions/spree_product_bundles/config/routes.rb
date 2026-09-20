# frozen_string_literal: true

# The storefront's bundle reads, wired through Spree's extension hook so nothing
# in core's routes file changes. The controllers inherit the Store API's base,
# so publishable-key auth, the guest gate and the error shape behave exactly like
# core resources.
#
# It lives in config/ rather than lib/ because this is the file Rails watches
# and re-loads: a routes reload re-draws the engine's routes, and a block
# registered once at boot from lib/ is not registered again, so the endpoint
# would vanish from a running development server until it restarted.
Spree::Core::Engine.add_routes do
  namespace :api, defaults: { format: 'json' } do
    namespace :v3 do
      # The operator's own surface: a set is created and edited from the panel,
      # so its CRUD is the Admin API's, with the same scopes and abilities every
      # other admin resource has.
      namespace :admin do
        resources :product_bundles, only: [:index, :show, :create, :update, :destroy]
      end

      namespace :store do
        # One collection and one member: the client's four calls differ in
        # filter rather than in shape.
        resources :product_bundles, only: [:index, :show], id: /.+/

        # The sets a cart holds, which a storefront renders as one card each.
        # Read-only: a bundle is added and removed through the cart's own items.
        resources :carts, only: [] do
          resources :product_bundles, only: [:index], controller: 'carts/product_bundles'
        end
      end
    end
  end
end
