require 'spec_helper'

RSpec.describe Spree::MembershipCards::Recycle do
  let(:store) { @default_store }
  let(:tier) { create(:membership_tier_setting, customer_group: create(:customer_group, store: store), rank: 1) }
  let(:group) { tier.customer_group }
  let(:customer) { create(:customer) }
  let(:card) { create(:membership_card, customer: customer, customer_group: group) }

  it 'voids a dormant card' do
    result = described_class.call(card: card, reason: 'reported lost')

    expect(result).to be_success
    expect(card.reload).to be_recycled
    expect(card.metadata['recycled_reason']).to eq('reported lost')
    expect(Spree::Membership.count).to eq(0)
  end

  # A voided card is not a broken one: activating it afterwards is refused, not
  # quietly allowed.
  it 'cannot be activated afterwards' do
    described_class.call(card: card)

    expect(Spree::MembershipCards::Activate.call(card: card.reload)).to be_failure
  end

  # The entitlement goes with the card, and the tier's group with the term.
  it 'takes an active card’s term with it' do
    Spree::MembershipCards::Activate.call(card: card)

    described_class.call(card: card.reload)

    expect(card.reload).to be_recycled
    expect(card.membership.reload).to be_cancelled
    expect(customer.reload.customer_groups).not_to include(group)
  end

  it 'answers a card it already voided' do
    described_class.call(card: card)

    expect(described_class.call(card: card.reload).value).to eq(card)
  end

  it 'refuses a card that already expired' do
    card.update!(status: 'expired')

    expect(described_class.call(card: card)).to be_failure
  end
end
