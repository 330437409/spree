require 'spec_helper'

RSpec.describe Spree::Grants::Kind do
  let(:store) { create(:store) }
  let(:customer) { create(:customer) }

  it 'names itself after its class, and a kind may pin that name instead' do
    expect(SpreeMembership::GrantKinds::Birthday.api_type).to eq('birthday')
    expect(SpecGrantKinds::Gift.api_type).to eq('spec_gift')
  end

  it 'leaves the key to the kind, and a kind that builds none is not one' do
    expect { described_class.idempotency_key_for('anything') }.to raise_error(NotImplementedError)
  end

  it 'counts as consumable and expiring until a kind says otherwise' do
    expect(described_class.consumable?).to be(true)
    expect(described_class.expires?).to be(true)
    expect(SpecGrantKinds::Card.consumable?).to be(false)
    expect(SpecGrantKinds::Card.expires?).to be(false)
  end

  it 'consumes a one-shot grant by stamping its row' do
    grant = create(:grant, store: store, customer: customer, kind: 'spec_gift')

    result = described_class.consume!(grant)

    expect(result).to be_success
    expect(grant.reload.status).to eq('consumed')
  end
end
