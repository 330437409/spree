require 'spec_helper'

RSpec.describe Spree::Membership, type: :model do
  let(:store) { @default_store }
  let(:tier) { create(:membership_tier_setting, customer_group: create(:customer_group, store: store), rank: 1) }
  let(:group) { tier.customer_group }
  let(:customer) { create(:customer) }

  it 'reaches its tier through the group both rows name' do
    membership = create(:membership, customer: customer, customer_group: group)

    expect(membership.tier_setting).to eq(tier)
    expect(membership.card).to be_nil
  end

  # One live term per customer per tier: a customer on two tiers is priced by
  # whichever catalogue sits lower, silently.
  it 'refuses a second live term on the same tier' do
    create(:membership, customer: customer, customer_group: group)

    expect { create(:membership, customer: customer, customer_group: group) }.
      to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'lets a customer hold a new term once the old one ended' do
    old = create(:membership, customer: customer, customer_group: group, status: 'expired')

    expect { create(:membership, customer: customer, customer_group: group) }.not_to raise_error
  end

  it 'refuses a window that ends before it starts' do
    expect(build(:membership, customer: customer, customer_group: group,
                              starts_at: Time.current, ends_at: 1.day.ago)).not_to be_valid
  end

  describe 'the scopes the sweep reads' do
    it 'counts a pending term as live and a running one as holding its tier' do
      waiting = create(:membership, customer: customer, customer_group: group, status: 'pending',
                                    starts_at: 1.day.from_now, ends_at: 30.days.from_now)
      other = create(:membership, customer: create(:customer), customer_group: group)

      expect(described_class.live).to include(waiting, other)
      expect(described_class.running).to include(other)
      expect(described_class.running).not_to include(waiting)
    end

    it 'finds the terms whose window closed, and the ones that opened' do
      closed = create(:membership, customer: customer, customer_group: group,
                                   starts_at: 1.hour.ago, ends_at: 1.minute.ago)
      waiting = create(:membership, customer: create(:customer), customer_group: group, status: 'pending',
                                    starts_at: 1.minute.ago, ends_at: 30.days.from_now)

      expect(described_class.due).to include(closed)
      expect(described_class.awaiting_start).to include(waiting)
    end
  end
end
