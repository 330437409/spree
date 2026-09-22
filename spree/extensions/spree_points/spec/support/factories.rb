FactoryBot.define do
  factory :point_account, class: 'Spree::PointAccount' do
    store
    customer
    kind { 'points' }
  end

  factory :point_reason, class: 'Spree::PointReason' do
    store
    sequence(:key) { |n| "reason_#{n}" }
    label { 'A reason an operator wrote' }
  end

  # The lot: a core grant row plus the side table that says how much of it is
  # left. The customer is the account's, because a lot belongs to a balance.
  factory :point_grant, class: 'Spree::PointGrant' do
    transient do
      expires_at { nil }
    end

    association :account, factory: :point_account
    grant do
      association :grant, store: account.store, customer: account.customer,
                         kind: 'point_lot', expires_at: expires_at
    end
    amount { 100 }
    remaining { 100 }
  end
end
