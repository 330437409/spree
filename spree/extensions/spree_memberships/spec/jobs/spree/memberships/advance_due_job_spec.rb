require 'spec_helper'

RSpec.describe Spree::Memberships::AdvanceDueJob do
  let(:store) { @default_store }
  let(:tier) { create(:membership_tier_setting, customer_group: create(:customer_group, store: store), rank: 1, validity_days: 30) }
  let(:group) { tier.customer_group }
  let(:customer) { create(:customer) }

  it 'ends every term whose window closed' do
    membership = create(:membership, customer: customer, customer_group: group,
                                     starts_at: 60.days.ago, ends_at: 1.minute.ago)

    described_class.perform_now

    expect(membership.reload).to be_expired
  end

  it 'leaves a term whose window is still open alone' do
    membership = create(:membership, customer: customer, customer_group: group, ends_at: 10.days.from_now)

    described_class.perform_now

    expect(membership.reload).to be_active
  end

  # The card's deadline is the sweep's other half: a card nobody activated in
  # time stops being activatable without anybody doing anything.
  it 'expires a dormant card whose deadline passed' do
    card = create(:membership_card, customer: customer, customer_group: group, activates_before: 1.minute.ago)

    described_class.perform_now

    expect(card.reload).to be_expired
  end

  it 'leaves a card with time left alone' do
    card = create(:membership_card, customer: customer, customer_group: group, activates_before: 1.day.from_now)

    described_class.perform_now

    expect(card.reload).to be_dormant
  end

  # One row nobody can advance must not stop the sweep for everything behind it:
  # the next run would start at the same row again.
  it 'keeps walking when one term cannot be advanced' do
    other = create(:membership_tier_setting, customer_group: create(:customer_group, store: store), rank: 2)
    create(:membership, customer: customer, customer_group: other.customer_group, ends_at: 5.days.from_now)
    Spree::Memberships::AssignTier.call(customer: customer, customer_group: other.customer_group)
    broken = create(:membership, customer: customer, customer_group: group, status: 'pending',
                                 starts_at: 1.minute.ago, ends_at: 30.days.from_now)
    customer.delete
    later = create(:membership, customer: create(:customer), customer_group: group,
                                starts_at: 60.days.ago, ends_at: 1.minute.ago)

    described_class.perform_now

    expect(broken.reload).to be_pending
    expect(later.reload).to be_expired
  end

  # An upgrade lands through the sweep: the term that ended is what lets the
  # customer's next one start.
  it 'starts the term waiting for the tier it replaces' do
    Spree::Memberships::AssignTier.call(customer: customer, customer_group: group)
    old = create(:membership, customer: customer, customer_group: group, starts_at: 60.days.ago, ends_at: 1.minute.ago)
    other = create(:membership_tier_setting, customer_group: create(:customer_group, store: store), rank: 2)
    waiting = create(:membership, customer: customer, customer_group: other.customer_group, status: 'pending',
                                  starts_at: 1.minute.ago, ends_at: 30.days.from_now)

    described_class.perform_now

    expect(old.reload).to be_expired
    expect(waiting.reload).to be_active
    expect(customer.reload.customer_groups).to contain_exactly(other.customer_group)
  end
end
