# frozen_string_literal: true

# Wired through Spree's extension hook so the endpoints are served under
# /api/v3/ without touching any core routes file, and drawn here rather than in
# lib/ because this is the file Rails watches and re-loads
# (docs/plans/6.1-membership-tiers-and-rights.md).
Spree::Core::Engine.add_routes do
  namespace :api, defaults: { format: 'json' } do
    namespace :v3 do
      namespace :store do
        # The rights catalogue — the flat list the member centre's sections are
        # a projection of — and the ladder itself.
        resources :membership_rights, only: [:index]
        resources :membership_tiers, only: [:index]

        namespace :customer, path: 'customers/me' do
          # The customer's own rung and what it carries.
          resource :membership, only: [:show], controller: 'membership'

          # The wallet, and the one transition the customer drives from it: 激活
          # is a resource of its own because it is a thing that happens once per
          # card, not an edit to the card.
          resources :membership_cards, only: [:index] do
            resources :activations, only: [:create], controller: 'membership_cards/activations'
          end
        end
      end

      namespace :admin do
        # A kind is chosen per request, so the picker the dashboard renders is
        # the registry's own list rather than a constant there.
        resources :membership_rights, only: [] do
          collection { get :types }
        end

        # A tier is a customer group, so its settings and its rights hang from
        # the group the operator already manages.
        resources :customer_groups, only: [] do
          resource :tier_setting, only: [:show, :create, :update], controller: 'customer_groups/tier_settings'
          resources :membership_rights, only: [:index, :show, :create, :update, :destroy],
                    controller: 'customer_groups/membership_rights'
        end

        # Read-only, both of them, with one write: a support desk has to be able
        # to void a card the client cannot, and that is its own resource rather
        # than an edit to a card that records what happened.
        resources :membership_cards, only: [:index, :show] do
          resource :recycling, only: [:create], controller: 'membership_cards/recycling'
        end
        resources :memberships, only: [:index, :show]
      end
    end
  end
end
