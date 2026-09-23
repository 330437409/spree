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

  # A term that has not started yet is one the customer never held: voiding the
  # card in the meantime has to work, and not write an end before its start.
  it 'voids a card whose term is still waiting' do
    other = create(:membership_tier_setting, customer_group: create(:customer_group, store: store), rank: 2)
    create(:membership, customer: customer, customer_group: other.customer_group, ends_at: 5.days.from_now)
    Spree::Memberships::AssignTier.call(customer: customer, customer_group: other.customer_group)
    Spree::MembershipCards::Activate.call(card: card)
    waiting = card.reload.membership

    result = described_class.call(card: card)

    expect(result).to be_success
    expect(waiting.reload).to be_cancelled
    expect(card.reload).to be_recycled
  end

  # Two cards of one tier share one term — the second extends the first's — so
  # voiding one gives back what that card added rather than ending what the
  # other paid for.
  it 'gives back only its own share of a term another card holds' do
    Spree::MembershipCards::Activate.call(card: card)
    term = card.reload.membership
    second = create(:membership_card, customer: customer, customer_group: group)
    Spree::MembershipCards::Activate.call(card: second)

    expect(term.reload.ends_at).to be_within(1.minute).of(730.days.from_now)

    described_class.call(card: second.reload)

    expect(card.reload).to be_active
    expect(term.reload).to be_active
    expect(term.ends_at).to be_within(1.minute).of(365.days.from_now)
    expect(customer.reload.customer_groups).to include(group)
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
