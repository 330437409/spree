FactoryBot.define do
  # A store's Tencent Cloud SMS account. Inactive by default so a spec that
  # needs the vendor says so, and the ones that assert a store cannot send do
  # not accidentally have an account.
  factory :spree_notifications_integration, class: 'SpreeNotifications::Integration' do
    store
    active { false }
    preferred_secret_id { 'AKIDEXAMPLE' }
    preferred_secret_key { 'SECRETEXAMPLE' }
    preferred_sms_sdk_app_id { '1400000000' }
    preferred_sign_name { '酒小二' }
    preferred_templates { { 'verification_code' => '1234567', 'payment_pin_code' => '7654321' } }
  end
end
