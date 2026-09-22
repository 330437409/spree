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
    association :account, factory: :point_account
    grant { association :grant, store: account.store, customer: account.customer, kind: 'point_lot' }
    amount { 100 }
    remaining { 100 }
  end
end
