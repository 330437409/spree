FactoryBot.define do
  factory :ledger_entry, class: 'Spree::LedgerEntry' do
    store
    # Any record can be an account in a spec; the service is what asks it for
    # the two contract methods.
    association :account, factory: :customer
    kind { 'earn' }
    unit { 'points' }
    amount { 10 }
    sequence(:idempotency_key) { |n| "ledger-key-#{n}" }
    occurred_at { Time.current }
  end
end
