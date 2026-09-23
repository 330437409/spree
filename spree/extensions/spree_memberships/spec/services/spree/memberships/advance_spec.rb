require 'spec_helper'

RSpec.describe Spree::Memberships::Advance do
  let(:store) { @default_store }
  let(:tier) { create(:membership_tier_setting, customer_group: create(:customer_group, store: store), rank: 1, validity_days: 30) }
  let(:group) { tier.customer_group }
  let(:customer) { create(:customer) }

  describe 'a term whose window opened' do
    # A purchased upgrade: it waits for the tier the customer holds, and takes
    # it when that one ends — the client's 自{lowEndTime}起 promise.
    it 'starts it and moves the tier’s group with it' do
      other = create(:membership_tier_setting, customer_group: create(:customer_group, store: store), rank: 2)
      Spree::Memberships::AssignTier.call(customer: customer, customer_group: other.customer_group)
      waiting = create(:membership, customer: customer, customer_group: group, status: 'pending',
                                    starts_at: 1.minute.ago, ends_at: 30.days.from_now)

      described_class.call(membership: waiting)

      expect(waiting.reload).to be_active
      expect(customer.reload.customer_groups).to contain_exactly(group)
    end
  end

  describe 'a term the tier renews by itself' do
    before { tier.update!(auto_renew: true) }

    # The new window runs from the instant the customer still holds — now, not
    # the instant the old one lapsed: nobody is being charged for the gap.
    it 'pushes the window forward from now' do
      membership = create(:membership, customer: customer, customer_group: group,
                                       starts_at: 30.days.ago, ends_at: 1.hour.ago)

      described_class.call(membership: membership)

      expect(membership.reload).to be_active
      expect(membership.starts_at).to be_within(1.minute).of(Time.current)
      expect(membership.ends_at).to be_within(1.minute).of(30.days.from_now)
    end
  end

  describe 'a term whose customer is gone' do
    # Spree adds no foreign keys, so a term can outlive its customer. There is
    # nobody for it to hold a tier for, and raising would stop the sweep for
    # every term behind it.
    it 'is left alone rather than raising' do
      other = create(:membership_tier_setting, customer_group: create(:customer_group, store: store), rank: 2)
      create(:membership, customer: customer, customer_group: other.customer_group, ends_at: 5.days.from_now)
      Spree::Memberships::AssignTier.call(customer: customer, customer_group: other.customer_group)
      waiting = create(:membership, customer: customer, customer_group: group, status: 'pending',
                                    starts_at: 1.minute.ago, ends_at: 30.days.from_now)
      customer.delete

      expect { described_class.call(membership: waiting.reload) }.not_to raise_error
      expect(waiting.reload).to be_pending
    end
  end

  describe 'a term that ran out' do
    before { tier.update!(grace_days: 7) }

    it 'sits in its grace window, still holding the tier' do
      membership = create(:membership, customer: customer, customer_group: group,
                                       starts_at: 30.days.ago, ends_at: 1.day.ago)
      Spree::Memberships::AssignTier.call(customer: customer, customer_group: group)

      described_class.call(membership: membership)

      expect(membership.reload).to be_past_due
      expect(customer.reload.customer_groups).to include(group)
    end

    it 'ends once the window closed, and leaves the group' do
      membership = create(:membership, customer: customer, customer_group: group,
                                       starts_at: 60.days.ago, ends_at: 8.days.ago)
      Spree::Memberships::AssignTier.call(customer: customer, customer_group: group)

      described_class.call(membership: membership)

      expect(membership.reload).to be_expired
      expect(customer.reload.customer_groups).not_to include(group)
    end

    # The days the customer paid for are the tier's own from now: a renewal
    # measured from a lapsed end would spend them inside the grace window.
    it 'renews from now when the term is already inside its grace window' do
      tier.update!(auto_renew: true, grace_days: 10)
      membership = create(:membership, customer: customer, customer_group: group,
                                       starts_at: 40.days.ago, ends_at: 5.days.ago)

      described_class.call(membership: membership)

      expect(membership.reload).to be_active
      expect(membership.ends_at).to be_within(1.minute).of(30.days.from_now)
    end

    # A term already waiting for this instant is what replaces this one: renewing
    # beside a successor leaves a tier that keeps renewing for a customer who has
    # moved on.
    it 'does not renew beside a term that is waiting to replace it' do
      tier.update!(auto_renew: true, grace_days: 0)
      other = create(:membership_tier_setting, customer_group: create(:customer_group, store: store), rank: 2)
      membership = create(:membership, customer: customer, customer_group: group,
                                       starts_at: 30.days.ago, ends_at: 1.hour.ago)
      create(:membership, customer: customer, customer_group: other.customer_group, status: 'pending',
                          starts_at: 1.hour.ago, ends_at: 30.days.from_now)

      described_class.call(membership: membership)

      expect(membership.reload).to be_expired
    end

    # With no grace window the term leaves the moment it ends.
    it 'ends straight away when the tier grants no grace' do
      tier.update!(grace_days: 0)
      membership = create(:membership, customer: customer, customer_group: group,
                                       starts_at: 30.days.ago, ends_at: 1.minute.ago)
      Spree::Memberships::AssignTier.call(customer: customer, customer_group: group)

      described_class.call(membership: membership)

      expect(membership.reload).to be_expired
    end
  end
end
