FactoryBot.define do
  # A tier: the group every tier is, plus the row that makes it one.
  factory :membership_tier_setting, class: 'Spree::MembershipTierSetting' do
    customer_group
    sequence(:rank) { |n| n }
    threshold { 100 }
    validity_days { 365 }
  end

  # One factory per kind: a kind is a class, so passing `type` as an attribute
  # would build the wrong one — the row would be right and the object in hand
  # would not.
  factory :membership_right, class: 'Spree::MembershipRights::ExclusiveCoupon' do
    customer_group
    published { true }
  end

  factory :coupon_right, parent: :membership_right, class: 'Spree::MembershipRights::Coupon'
  factory :member_price_right, parent: :membership_right, class: 'Spree::MembershipRights::MemberPrice'
  factory :birthday_right, parent: :membership_right, class: 'Spree::MembershipRights::BirthdayDoubleIntegral'
end
