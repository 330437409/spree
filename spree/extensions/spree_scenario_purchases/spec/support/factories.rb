FactoryBot.define do
  factory :scenario_order, class: 'Spree::ScenarioOrder' do
    store
    customer
    kind { 'simple' }
    payment_channel { 'wechat' }
    status { 'pending' }
    amount { 10 }
    currency { 'USD' }
  end

  factory :scenario_payment_session, class: 'Spree::PaymentSessions::Bogus' do
    type { 'Spree::PaymentSessions::Bogus' }
    scenario_order
    payment_method { create(:bogus_payment_method, store: scenario_order.store) }
    amount { scenario_order.amount }
    currency { scenario_order.currency }
    status { 'pending' }
    external_id { "scn_#{SecureRandom.hex(12)}" }
    expires_at { 24.hours.from_now }
  end
end
