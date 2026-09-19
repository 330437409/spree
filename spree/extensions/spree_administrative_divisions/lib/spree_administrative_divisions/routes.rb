# frozen_string_literal: true

# The tree's Store endpoint, wired through Spree's extension hook so it is
# served at /api/v3/store/administrative_divisions without touching any core
# routes file. The controller inherits the Store API's base, so publishable-key
# auth, the guest gate and the error shape behave exactly like core resources.
#
# Required from lib/spree_administrative_divisions.rb, early, so the block is
# registered before Spree draws its routes.
Spree::Core::Engine.add_routes do
  namespace :api, defaults: { format: 'json' } do
    namespace :v3 do
      namespace :store do
        resources :administrative_divisions, only: [:index]
      end
    end
  end
end
