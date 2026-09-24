FactoryBot.define do
  # A tier: the group every tier is, plus the row that makes it one.
  factory :membership_tier_setting, class: 'Spree::MembershipTierSetting' do
    customer_group
    sequence(:rank) { |n| n }
    threshold { 100 }
    validity_days { 365 }
  end

  # A card, before anybody is entitled to anything. Point it at a tier's group
  # to make it activatable: only a group that is a tier can be assigned.
  factory :membership_card, class: 'Spree::MembershipCard' do
    customer
    customer_group
    source { 'purchase' }
  end

  # The purchase a card was issued for. The scenario gem keeps its own factory
  # in its specs, so this is the smallest one this gem's specs need.
  factory :scenario_order, class: 'Spree::ScenarioOrder' do
    store
    customer
    kind { 'card_purchase' }
    payment_channel { 'wechat' }
    status { 'pending' }
    amount { 100 }
    currency { 'USD' }
  end

  # A period a customer holds a tier for.
  factory :membership, class: 'Spree::Membership' do
    customer
    customer_group
    status { 'active' }
    starts_at { Time.current }
    ends_at { 1.year.from_now }
  end

  # One factory per kind: a kind is a class, so passing `type` as an attribute
  # would build the wrong one — the row would be right and the object in hand
  # would not.
  factory :membership_right, class: 'Spree::MembershipRights::ExclusiveCoupon' do
    customer_group
    published { true }
  end

  factory :coupon_right, parent: :membership_right, class: 'Spree::MembershipRights::Coupon'
  factory :entry_integral_right, parent: :membership_right, class: 'Spree::MembershipRights::EntryIntegral'
  factory :member_price_right, parent: :membership_right, class: 'Spree::MembershipRights::MemberPrice'
  factory :birthday_right, parent: :membership_right, class: 'Spree::MembershipRights::BirthdayDoubleIntegral'
  factory :give_gift_right, parent: :membership_right, class: 'Spree::MembershipRights::GiveGift'
end
