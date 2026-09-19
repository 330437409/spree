require 'spec_helper'

RSpec.describe SpreeServiceAreas::ServiceAreaRequirement do
  subject(:requirement) { described_class.new(store: store) }

  include_context 'the division tree around 天安门'

  let(:store) { create(:store) }
  let(:seller) { create(:seller, :approved, store: store) }

  it 'is a kind the operator can put on a checklist' do
    expect(Spree.seller_requirements).to include(described_class)
  end

  it 'is met by a warehouse bound to a division' do
    create(:stock_location, seller: seller, store: store, administrative_division: dongcheng)

    expect(requirement.satisfied?(seller)).to be true
  end

  it 'is not met by a warehouse with no binding' do
    create(:stock_location, seller: seller, store: store, administrative_division: nil)

    expect(requirement.satisfied?(seller)).to be false
  end

  it 'is not met by a warehouse that was deactivated' do
    create(:stock_location, seller: seller, store: store, administrative_division: dongcheng, active: false)

    expect(requirement.satisfied?(seller)).to be false
  end

  it 'is not met by a seller with no warehouse at all' do
    expect(requirement.satisfied?(seller)).to be false
  end
end
