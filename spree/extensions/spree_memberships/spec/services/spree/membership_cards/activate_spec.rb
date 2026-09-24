require 'spec_helper'

RSpec.describe Spree::MembershipCards::Activate do
  let(:store) { @default_store }
  let(:tier) { create(:membership_tier_setting, customer_group: create(:customer_group, store: store), rank: 1) }
  let(:group) { tier.customer_group }
  let(:customer) { create(:customer) }
  let(:card) { create(:membership_card, customer: customer, customer_group: group) }

  it 'turns a dormant card into a term for its buyer' do
    result = described_class.call(card: card)

    expect(result).to be_success
    expect(card.reload).to be_active
    expect(card.membership).to be_active
    expect(card.activated_by_customer).to eq(customer)
  end

  it 'puts the customer on the tier, which is what member pricing reads' do
    described_class.call(card: card)

    expect(customer.reload.customer_groups).to include(group)
  end

  it 'gives the term the tier’s own length' do
    tier.update!(validity_days: 30)

    described_class.call(card: card)

    expect(card.reload.membership.ends_at).to be_within(1.minute).of(30.days.from_now)
  end

  # 转赠 is the same transition from another door: the entitlement goes to
  # whoever activated it, and the card stays in the buyer's record.
  it 'starts the term for whoever claimed it' do
    claimer = create(:customer)

    described_class.call(card: card, customer: claimer)

    expect(card.reload.customer).to eq(customer)
    expect(card.activated_by_customer).to eq(claimer)
    expect(card.membership.customer).to eq(claimer)
    expect(claimer.reload.customer_groups).to include(group)
    expect(customer.reload.customer_groups).not_to include(group)
  end

  it 'extends the term the customer already holds on that tier' do
    membership = create(:membership, customer: customer, customer_group: group, ends_at: 10.days.from_now)

    described_class.call(card: card)

    expect(membership.reload.ends_at).to be_within(1.minute).of(365.days.from_now + 10.days)
    expect(Spree::Membership.where(customer: customer).count).to eq(1)
  end

  # The client's own warning: 自{lowEndTime}起，您的权益将变更为… — the tier the
  # customer holds now keeps them until its term ends.
  it 'waits for the tier the customer holds now' do
    other_tier = another_tier
    running = create(:membership, customer: customer, customer_group: other_tier.customer_group, ends_at: 5.days.from_now)
    Spree::Memberships::AssignTier.call(customer: customer, customer_group: other_tier.customer_group)

    described_class.call(card: card)

    waiting = card.reload.membership
    expect(waiting).to be_pending
    expect(waiting.starts_at).to be_within(1.minute).of(running.ends_at)
    expect(customer.reload.customer_groups).to contain_exactly(other_tier.customer_group)
  end

  # A retry, a double tap: the answer is the card it already activated.
  it 'answers a card it already activated' do
    first = described_class.call(card: card)

    expect(described_class.call(card: card.reload).value).to eq(first.value)
    expect(Spree::Membership.count).to eq(1)
  end

  it 'refuses a card whose deadline passed, and expires it' do
    card.update!(activates_before: 1.day.ago)

    result = described_class.call(card: card)

    expect(result).to be_failure
    expect(card.reload).to be_expired
    expect(Spree::Membership.count).to eq(0)
  end

  it 'refuses a card for a tier nobody sells any more' do
    tier.destroy

    result = described_class.call(card: card)

    expect(result).to be_failure
    expect(card.reload).to be_dormant
    expect(Spree::Membership.count).to eq(0)
  end

  # What this card added, so voiding it can take back exactly that much.
  it 'records what the card granted' do
    described_class.call(card: card)

    expect(card.reload.metadata['granted_days']).to eq(365)
  end

  # A tier held with no end is held for good: a card bought under one waits for
  # a person, not for a clock, and the customer's money stays unspent.
  it 'refuses to wait for a tier that has no end' do
    other = create(:membership_tier_setting, customer_group: create(:customer_group, store: store), rank: 2)
    create(:membership, customer: customer, customer_group: other.customer_group, ends_at: nil)
    Spree::Memberships::AssignTier.call(customer: customer, customer_group: other.customer_group)

    result = described_class.call(card: card)

    expect(result).to be_failure
    expect(card.reload).to be_dormant
  end

  # The customer paid to keep a tier they are inside the grace window of: the
  # new window runs from now, and the term holds the tier again.
  it 'brings a lapsed term back, measuring from now' do
    lapsed = create(:membership, customer: customer, customer_group: group, status: 'past_due',
                                 starts_at: 60.days.ago, ends_at: 5.days.ago)

    described_class.call(card: card)

    expect(lapsed.reload).to be_active
    expect(lapsed.ends_at).to be_within(1.minute).of(365.days.from_now)
  end

  # The ladder's uniqueness is over live terms, so a card for a tier the
  # customer is already waiting for extends that wait rather than writing a
  # second one the index would refuse.
  it 'extends the waiting term it already wrote for that tier' do
    other = create(:membership_tier_setting, customer_group: create(:customer_group, store: store), rank: 2)
    create(:membership, customer: customer, customer_group: other.customer_group, ends_at: 5.days.from_now)
    Spree::Memberships::AssignTier.call(customer: customer, customer_group: other.customer_group)
    described_class.call(card: card)
    waiting = card.reload.membership

    second = create(:membership_card, customer: customer, customer_group: group)
    described_class.call(card: second)

    # The wait it already covers, plus this card's year: the customer bought a
    # second year of a tier they are waiting for.
    expect(second.reload.membership).to eq(waiting)
    expect(waiting.reload.ends_at).to be_within(1.minute).of(370.days.from_now + 365.days)
    expect(Spree::Membership.where(customer: customer, customer_group: group).count).to eq(1)
  end

  it 'refuses a card that was already voided' do
    card.update!(status: 'recycled')

    expect(described_class.call(card: card)).to be_failure
  end
end
