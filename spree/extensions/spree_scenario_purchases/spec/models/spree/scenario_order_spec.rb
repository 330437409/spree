require 'spec_helper'

RSpec.describe Spree::ScenarioOrder, type: :model do
  let(:store) { @default_store }
  let(:scenario_order) { create(:scenario_order, store: store) }

  it 'registers the kinds a deployment sells' do
    expect(described_class.available_kinds.map(&:api_type)).to include('simple')
    expect(described_class.kind_for('simple')).to eq(Spree::ScenarioOrders::TestKinds::Simple)
    expect(described_class.kind_for(:simple)).to eq(Spree::ScenarioOrders::TestKinds::Simple)
  end

  # A row naming a kind no gem registered is a purchase nothing can hand over.
  it 'refuses a kind nothing registered' do
    expect(build(:scenario_order, store: store, kind: 'lottery')).not_to be_valid
  end

  it 'needs an amount and a currency' do
    expect(build(:scenario_order, store: store, amount: -1)).not_to be_valid
    expect(build(:scenario_order, store: store, currency: nil)).not_to be_valid
  end

  it 'moves through the frame\'s own statuses' do
    expect(scenario_order).to be_pending
    expect(described_class.statuses).to eq(%w[pending paying paid canceled expired])
  end

  # What the gateway asks of whatever a session is for.
  it 'answers the gateway the way an order does' do
    expect(scenario_order.total_minus_store_credits).to eq(scenario_order.amount)
    expect(scenario_order.currency).to eq('USD')
    expect(scenario_order.customer).to be_present
    expect(scenario_order.number).to eq(scenario_order.prefixed_id)
  end

  it 'has no session until one is opened' do
    expect(scenario_order.payment_session).to be_nil
  end

  # What core's webhook workflow asks before it settles a session: an owner that
  # cannot answer fails the settlement it was called for, and the notification
  # is answered 200 either way.
  it 'is complete from the moment it exists' do
    expect(scenario_order).to be_completed
  end

  it 'has nothing to refresh when a payment of it is destroyed' do
    expect { scenario_order.refresh_payment_total! }.not_to raise_error
  end

  # A settled purchase has handed over what was bought, and the row is the
  # record of it; only an open one leaves the customer's list.
  it 'stays in the history once it is paid, and can be removed while it is not' do
    expect(scenario_order.can_be_deleted?).to be(true)

    scenario_order.update!(status: 'paid')
    expect(scenario_order.can_be_deleted?).to be(false)
  end

  it 'belongs to nobody in particular when asked for a nil customer' do
    create(:scenario_order, store: store, customer: nil)

    expect(described_class.for_customer(nil)).to be_empty
  end
end
