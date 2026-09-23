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

    it 'pushes the window forward from where it ended' do
      membership = create(:membership, customer: customer, customer_group: group,
                                       starts_at: 30.days.ago, ends_at: 1.hour.ago)

      described_class.call(membership: membership)

      expect(membership.reload).to be_active
      expect(membership.starts_at).to be_within(1.minute).of(1.hour.ago)
      expect(membership.ends_at).to be_within(1.minute).of(1.hour.ago + 30.days)
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
