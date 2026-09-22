require 'spec_helper'

RSpec.describe Spree::ScenarioOrders::Expire do
  let(:store) { @default_store }

  it 'closes purchases whose window passed without a settlement' do
    lapsed = create(:scenario_order, store: store, status: 'paying')
    fresh = create(:scenario_order, store: store, status: 'paying')
    create(:scenario_payment_session, scenario_order: lapsed, expires_at: 1.hour.ago)
    create(:scenario_payment_session, scenario_order: fresh, expires_at: 1.hour.from_now)

    result = described_class.call

    expect(result.value).to eq(1)
    expect(lapsed.reload).to be_expired
    expect(fresh.reload).to be_paying
  end
end
