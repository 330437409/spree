require 'spec_helper'

RSpec.describe Spree::MembershipCard, type: :model do
  let(:store) { @default_store }
  let(:tier) { create(:membership_tier_setting, customer_group: create(:customer_group, store: store), rank: 1) }
  let(:group) { tier.customer_group }
  let(:customer) { create(:customer) }

  it 'is born dormant, owned by its buyer' do
    card = create(:membership_card, customer: customer, customer_group: group)

    expect(card).to be_dormant
    expect(card).to be_giftable
    expect(card.tier_setting).to eq(tier)
  end

  it 'refuses a group from another store' do
    other_store = create(:store)
    other_group = create(:customer_group, store: other_store)

    expect(build(:membership_card, customer: customer, customer_group: other_group, store: store)).not_to be_valid
  end

  it 'refuses a source that is not a purchase or a grant' do
    expect(build(:membership_card, customer: customer, customer_group: group, source: 'given')).not_to be_valid
  end

  # One card per purchase: the settlement can retry, and the retry has to find
  # the card it already issued.
  it 'refuses a second card for one purchase' do
    order = create(:scenario_order)
    create(:membership_card, customer: customer, customer_group: group, scenario_order: order)

    expect { create(:membership_card, customer: customer, customer_group: group, scenario_order: order) }.
      to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'lets granted cards share no purchase at all' do
    expect {
      2.times { create(:membership_card, customer: customer, customer_group: group) }
    }.not_to raise_error
  end

  describe 'the deadline to activate it' do
    it 'is overdue only once it has passed' do
      card = create(:membership_card, customer: customer, customer_group: group, activates_before: 1.hour.from_now)

      expect(card).not_to be_overdue

      card.update!(activates_before: 1.hour.ago)
      expect(card).to be_overdue
    end

    it 'is never overdue once the card was activated' do
      card = create(:membership_card, customer: customer, customer_group: group,
                                      activates_before: 1.hour.ago, status: 'active')

      expect(card).not_to be_overdue
    end
  end

  it 'counts only the dormant, giftable cards as a wallet to give from' do
    dormant = create(:membership_card, customer: customer, customer_group: group)
    create(:membership_card, customer: customer, customer_group: group, giftable: false)
    create(:membership_card, customer: customer, customer_group: group, status: 'active')

    expect(described_class.for_customer(customer).giftable).to contain_exactly(dormant)
  end
end
