require 'spec_helper'

RSpec.describe Spree::ScenarioOrders::Cancel do
  let(:scenario_order) { create(:scenario_order, store: @default_store) }

  it 'calls off a purchase that was not paid for' do
    result = described_class.call(scenario_order: scenario_order)

    expect(result).to be_success
    expect(scenario_order.reload).to be_canceled
    expect(scenario_order.metadata['issued']).to be_nil
  end

  it 'refuses one that was paid for' do
    scenario_order.update!(status: 'paid')

    expect(described_class.call(scenario_order: scenario_order)).to be_failure
  end

  it 'refuses one already called off' do
    described_class.call(scenario_order: scenario_order)

    expect(described_class.call(scenario_order: scenario_order)).to be_failure
  end
end
