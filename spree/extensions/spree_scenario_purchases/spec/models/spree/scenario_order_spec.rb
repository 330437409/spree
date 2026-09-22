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
end
