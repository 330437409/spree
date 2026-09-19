FactoryBot.define do
  factory :flash_sale, class: 'Spree::FlashSale' do
    store { Spree::Store.default || create(:store) }
    sequence(:title) { |n| "秒杀专场 #{n}" }
    code { 'seckill' }
    status { 'live' }
    starts_at { 1.hour.ago }
    ends_at { 2.hours.from_now }
    pool_all { 10 }
    pool_per_day { 10 }
    pool_per_slot { 10 }

    trait :scheduled do
      status { 'scheduled' }
      starts_at { 1.hour.from_now }
      ends_at { 3.hours.from_now }
    end

    trait :ended do
      status { 'ended' }
      starts_at { 3.hours.ago }
      ends_at { 1.hour.ago }
    end

    trait :with_slot do
      after(:create) do |flash_sale|
        create(:flash_sale_slot, flash_sale: flash_sale, pool: flash_sale.pool_per_slot)
      end
    end
  end

  factory :flash_sale_slot, class: 'Spree::FlashSale::Slot' do
    flash_sale
    starts_at { 10.minutes.ago }
    ends_at { 50.minutes.from_now }
    pool { 10 }
  end

  factory :flash_sale_item, class: 'Spree::FlashSale::Item' do
    flash_sale
    variant
    sale_amount { 9.9 }
    pool { 10 }
  end

  factory :flash_sale_ticket, class: 'Spree::FlashSaleTicket' do
    store { Spree::Store.default || create(:store) }
    flash_sale
    variant
    customer
    quantity { 1 }
    status { 'holding' }
    expires_at { 5.minutes.from_now }
  end

  factory :pool_hold, class: 'Spree::PoolHold' do
    pool { Spree::FlashSale::Pool.for!(flash_sale: create(:flash_sale), kind: 'all') }
    owner { association(:flash_sale_ticket) }
    quantity { 1 }
    expires_at { 5.minutes.from_now }
    status { 'holding' }
  end

  factory :flash_sale_reminder, class: 'Spree::FlashSale::Reminder' do
    store { Spree::Store.default || create(:store) }
    flash_sale
    slot { association(:flash_sale_slot, flash_sale: flash_sale) }
    customer
  end
end
