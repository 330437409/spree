FactoryBot.define do
  # A promotion that issues individual codes. Only such a promotion has code
  # rows, so only such a promotion can feed a wallet.
  factory :coupon_wallet_promotion, parent: :promotion do
    multi_codes { true }
    number_of_codes { 3 }
  end

  factory :coupon_campaign, class: 'Spree::CouponCampaigns::Draw' do
    store
    name { 'A draw' }
    status { 'active' }
    starts_at { 1.hour.ago }
    promotion { association :coupon_wallet_promotion, store: store }
  end

  factory :new_customer_coupon_campaign, parent: :coupon_campaign,
                                         class: 'Spree::CouponCampaigns::NewCustomer'
  factory :site_coupon_campaign, parent: :coupon_campaign,
                                 class: 'Spree::CouponCampaigns::SiteScoped'

  factory :coupon_holding, class: 'Spree::CouponHolding' do
    transient do
      store { Spree::Store.find_by(default: true) || association(:store) }
      customer { association(:customer) }
    end

    source { 'admin' }
    grant do
      association :grant, store: store, customer: customer, kind: 'coupon_holding',
                          idempotency_key: "coupon_holding:#{SecureRandom.hex(6)}"
    end
    coupon_code { association :coupon_code, promotion: association(:coupon_wallet_promotion, store: store) }
  end
end
