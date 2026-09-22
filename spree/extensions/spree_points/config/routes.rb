# frozen_string_literal: true

# Wired through Spree's extension hook so the endpoints are served under
# /api/v3/ without touching any core routes file, and drawn here rather than in
# lib/ because this is the file Rails watches and re-loads
# (docs/plans/6.1-points-and-growth-value.md).
Spree::Core::Engine.add_routes do
  namespace :api, defaults: { format: 'json' } do
    namespace :v3 do
      namespace :store do
        # The points shop: one collection answers the client's page, its
        # category tabs, the featured shelf and the member shelf between them —
        # they differ in filter rather than in shape — and one member. The
        # category labels the tabs read come back in the collection's own meta.
        resources :point_products, only: [:index, :show]

        # The customer's own balances and their history, under the same
        # `customers/me` namespace the rest of the customer's own reads use.
        namespace :customer, path: 'customers/me' do
          # The collection is both balances rather than a list of rows: a
          # customer who has never earned has no account, and the read still
          # answers two zero balances. `:kind` is the member's own parameter —
          # a balance is named, not numbered.
          resources :point_accounts, only: [:index]
          # Drawn rather than nested: a balance is named by its kind, and the
          # nesting macro would rename the segment to the parent's own
          # `:point_account_kind`.
          get 'point_accounts/:kind/transactions', to: 'point_accounts/transactions#index',
              as: :point_account_transactions
        end
      end
    end
  end
end
