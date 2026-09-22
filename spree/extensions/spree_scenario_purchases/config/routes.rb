# frozen_string_literal: true

# Wired through Spree's extension hook so the endpoints are served under
# /api/v3/ without touching any core routes file, and drawn here rather than in
# lib/ because this is the file Rails watches and re-loads
# (docs/plans/6.1-scenario-purchases.md).
Spree::Core::Engine.add_routes do
  namespace :api, defaults: { format: 'json' } do
    namespace :v3 do
      namespace :store do
        # What can be bought here and how it is paid for, in one payload for
        # the client's pay-config and pay-setting calls.
        resource :pay_config, only: [:show], controller: 'pay_config'

        # One create for every scenario and every channel; one member, and the
        # cancellation a customer makes instead of a `cancel` action.
        resources :scenario_orders, only: [:create, :show, :destroy] do
          resource :cancellation, only: [:create], controller: 'scenario_orders/cancellations'
        end

        # The customer's own purchases, which is what the unpaid screens list.
        namespace :customer, path: 'customers/me' do
          resources :scenario_orders, only: [:index]
        end
      end
    end
  end
end
