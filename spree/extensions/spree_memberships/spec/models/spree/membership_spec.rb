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
      to raise_error(ActiveRecord::RecordInvalid)
  end

  # The validation is the readable half of the rule; the index is the half that
  # holds when a bulk writer never asks.
  #
  # Asserted from the schema rather than by provoking it: a refused insert
  # poisons the surrounding transaction on PostgreSQL — the cleanup then fails
  # rather than the assertion — and a savepoint around it leaves MySQL with a
  # dangling one. The index is the fact worth checking either way.
  it 'is enforced by the database too' do
    index = Spree::Membership.connection.indexes(:spree_memberships).
            find { |candidate| candidate.name == 'index_memberships_on_customer_group_live' }

    expect(index).to be_present
    expect(index.unique).to be(true)
    # Partial where the adapter has partial indexes — the two columns — and over
    # the stored key where it does not (MySQL and MariaDB), exactly as the
    # migration writes it. The uniqueness is the same fact either way.
    expect(index.columns).to(
      include('customer_id', 'customer_group_id').or contain_exactly('live_key')
    )
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

    # What the sweep has something to say about: a term whose window closed and
    # one whose window opened — and not a term still inside its window, which is
    # what keeps an hourly pass off every live term a store has.
    it 'finds the terms whose window closed, and the ones that opened' do
      closed = create(:membership, customer: customer, customer_group: group,
                                   starts_at: 1.hour.ago, ends_at: 1.minute.ago)
      opening = create(:membership, customer: create(:customer), customer_group: group, status: 'pending',
                                    starts_at: 1.minute.ago, ends_at: 30.days.from_now)
      open_now = create(:membership, customer: create(:customer), customer_group: group,
                                     starts_at: 1.hour.ago, ends_at: 30.days.from_now)

      expect(described_class.due).to include(closed, opening)
      expect(described_class.due).not_to include(open_now)
    end
  end
end
