require 'spec_helper'

RSpec.describe Spree::ScenarioOrders::Settle do
  let(:scenario_order) { create(:scenario_order, store: @default_store, status: 'paying') }

  it 'marks the purchase paid and hands the kind what it bought' do
    result = described_class.call(scenario_order: scenario_order)

    expect(result).to be_success
    expect(scenario_order.reload).to be_paid
    expect(scenario_order.metadata['issued']).to eq(1)
  end

  # The webhook can arrive more than once, and the customer's own return races
  # it: the second arrival must grant nothing.
  it 'issues once however many times it is asked' do
    described_class.call(scenario_order: scenario_order)
    described_class.call(scenario_order: scenario_order)

    expect(scenario_order.reload.metadata['issued']).to eq(1)
  end
end
