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

        # What a settled purchase released, read back off the purchase: the
        # purchase is the scenario plan's row and the card is this gem's, so only
        # this nested read is drawn here
        # (docs/plans/6.1-membership-tiers-and-rights.md, and the ruling in
        # fork-decisions.md).
        resources :scenario_orders, only: [] do
          resource :membership_card, only: [:show], controller: 'scenario_orders/membership_cards'
        end

        namespace :customer, path: 'customers/me' do
          # The customer's own rung and what it carries.
          resource :membership, only: [:show], controller: 'membership'

          # The banner their member centre opens with, resolved from their tier.
          resource :membership_banner, only: [:show], controller: 'membership_banner'

          # What a member claims of a right — the right is the tier's, and the
          # claim is theirs — and 立即领取 is the only one so far.
          resources :membership_rights, only: [] do
            resources :year_gift_claims, only: [:create], controller: 'membership_rights/year_gift_claims'
          end

          # The wallet, and the one transition the customer drives from it: 激活
          # is a resource of its own because it is a thing that happens once per
          # card, not an edit to the card.
          resources :membership_cards, only: [:index] do
            resources :activations, only: [:create], controller: 'membership_cards/activations'
            # 相赠 and 作废: the window a card is inside. Cancelling one is its
            # removal, which is what the client's cancel does.
            resources :transfers, only: [:index, :create, :destroy], controller: 'membership_cards/transfers'
          end
        end

        # The recipient's side, addressed by the token rather than by the card:
        # the card is read before signing in, and the claim is where they sign
        # in. Deliberately not under customers/me — a gift is not the giver's.
        resources :membership_card_transfers, only: [:show], param: :token,
                  controller: 'membership_card_transfers' do
          resources :claims, only: [:create], controller: 'membership_card_transfers/claims'
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
          # The banner that tier's members see: a group has at most one.
          resource :banner, only: [:show, :create, :update], controller: 'customer_groups/banners'
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
