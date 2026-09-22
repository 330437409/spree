# frozen_string_literal: true

# Wired through Spree's extension hook so the endpoints are served under
# /api/v3/ without touching any core routes file, and drawn here rather than in
# lib/ because this is the file Rails watches and re-loads
# (docs/plans/6.1-coupon-wallet.md).
Spree::Core::Engine.add_routes do
  namespace :api, defaults: { format: 'json' } do
    namespace :v3 do
      namespace :store do
        # The customer's own wallet. A code the customer already has is claimed
        # by creating a holding, which is what entering it is.
        namespace :customer, path: 'customers/me' do
          resources :coupon_holdings, only: [:index, :show, :create]
        end

        # One draw against a campaign, as a resource of its own: a draw is a
        # thing that happens and is recorded, not an action on the campaign,
        # and what it answers with is the coupon it won.
        resources :coupon_campaigns, only: [] do
          resources :draws, only: [:create], controller: 'coupon_campaigns/draws'
        end
      end
    end
  end
end
