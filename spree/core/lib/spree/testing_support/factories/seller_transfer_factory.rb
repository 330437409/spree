FactoryBot.define do
  factory :seller_transfer, class: Spree::SellerTransfer do
    seller
    store { seller.store }
    order
    amount { BigDecimal(20) }
    currency { 'USD' }
    kind { 'earning' }
    provider { Spree::PayoutProvider::System.provider_key }
    status { 'pending' }

    trait :completed do
      status { 'completed' }
    end

    trait :reversal do
      kind { 'refund_reversal' }
      amount { BigDecimal(-5) }
    end

    # What the platform owes the seller on top of their earning, when it funded
    # part of the price.
    trait :subsidy do
      kind { 'subsidy' }
    end
  end
end
