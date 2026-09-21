FactoryBot.define do
  # A code as the send leaves it: a digest on the row and the plaintext known
  # only to whoever asked for it — which in a spec is the example itself.
  factory :verification_code, class: 'Spree::VerificationCode' do
    store
    sequence(:phone) { |n| format('138%08d', n) }
    purpose { 'account' }
    channel { 'sms' }
    code { '123456' }
    expires_at { 5.minutes.from_now }
  end

  factory :payment_pin, class: 'Spree::PaymentPin' do
    store
    customer
    pin { '246813' }
    required { true }
  end
end
