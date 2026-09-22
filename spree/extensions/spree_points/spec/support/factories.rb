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

FactoryBot.define do
  factory :point_product, class: 'Spree::PointProducts::Good' do
    store
    sequence(:name) { |n| "Points good #{n}" }
    points { 100 }
    money { 0 }
    stock { 10 }
    variant
  end

  # One factory per kind: a kind is a class, so passing `type` as an attribute
  # would build the wrong one. Each carries only what its own kind uses — the
  # shippable good's variant is not an attribute of a coupon good.
  factory :point_coupon_product, class: 'Spree::PointProducts::Coupon' do
    store
    sequence(:name) { |n| "Points coupon #{n}" }
    points { 100 }
    stock { 10 }
  end

  factory :point_vip_card_product, class: 'Spree::PointProducts::VipCard' do
    store
    sequence(:name) { |n| "Points card #{n}" }
    points { 100 }
    stock { 10 }
    customer_group
  end
end
