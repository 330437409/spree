require 'spec_helper'

RSpec.describe Spree::Memberships::EndTerm do
  let(:store) { @default_store }
  let(:tier) { create(:membership_tier_setting, customer_group: create(:customer_group, store: store), rank: 1) }
  let(:group) { tier.customer_group }
  let(:customer) { create(:customer) }

  before { Spree::Memberships::AssignTier.call(customer: customer, customer_group: group) }

  it 'ends the term and leaves the tier’s group in the same step' do
    membership = create(:membership, customer: customer, customer_group: group)

    described_class.call(membership: membership)

    expect(membership.reload).to be_expired
    expect(customer.reload.customer_groups).not_to include(group)
  end

  # A cancellation cuts the window short — the instant the client renders is
  # what it was, not what it would have been.
  it 'writes the instant a cancellation happened' do
    membership = create(:membership, customer: customer, customer_group: group, ends_at: 10.days.from_now)

    described_class.call(membership: membership, status: 'cancelled')

    expect(membership.reload).to be_cancelled
    expect(membership.ends_at).to be_within(1.minute).of(Time.current)
  end

  # An upgrade leaves this behind: the old term ends after the new one has
  # already started, so leaving every tier would take the new one away.
  it 'leaves the new tier alone when an old term ends after it started' do
    other = create(:membership_tier_setting, customer_group: create(:customer_group, store: store), rank: 2)
    create(:membership, customer: customer, customer_group: other.customer_group, ends_at: 30.days.from_now)
    Spree::Memberships::AssignTier.call(customer: customer, customer_group: other.customer_group)
    old = create(:membership, customer: customer, customer_group: group, ends_at: 1.minute.from_now)

    described_class.call(membership: old)

    expect(customer.reload.customer_groups).to contain_exactly(other.customer_group)
  end

  # The sweep runs again on its next pass, and a term it already ended is its
  # own work rather than a mistake.
  it 'answers a term that already ended' do
    membership = create(:membership, customer: customer, customer_group: group, status: 'expired')

    expect(described_class.call(membership: membership)).to be_success
  end
end
