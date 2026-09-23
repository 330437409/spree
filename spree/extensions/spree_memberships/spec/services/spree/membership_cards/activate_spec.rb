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
    other_tier = create(:membership_tier_setting, customer_group: create(:customer_group, store: store), rank: 2)
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

  it 'refuses a card that was already voided' do
    card.update!(status: 'recycled')

    expect(described_class.call(card: card)).to be_failure
  end
end
