FactoryBot.define do
  factory :grant, class: 'Spree::Grant' do
    store
    customer
    # A kind names a registered class; a spec that needs one registers it, and
    # a spec that does not gets a kind no registry knows.
    kind { 'spec_kind' }
    sequence(:idempotency_key) { |n| "grant-key-#{n}" }
    granted_at { Time.current }
  end
end
