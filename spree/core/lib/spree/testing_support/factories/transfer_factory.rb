FactoryBot.define do
  # The thing being moved is always passed in: a transfer carries a coupon
  # holding, a gift card or a membership card, and only the caller knows which.
  factory :transfer, class: Spree::Transfer do
    store { Spree::Store.default || association(:store) }
    from_customer { association(:customer) }
    sequence(:to_phone) { |n| "1380000#{n.to_s.rjust(4, '0')}" }
    expires_at { 7.days.from_now }
    status { 'pending' }
  end
end
