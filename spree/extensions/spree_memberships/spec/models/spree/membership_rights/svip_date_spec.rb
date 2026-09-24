require 'spec_helper'

RSpec.describe Spree::MembershipRights::SvipDate, type: :model do
  let(:store) { @default_store }
  let(:group) { create(:customer_group, store: store) }
  let!(:tier) { create(:membership_tier_setting, customer_group: group, rank: 1) }

  def day(preferences)
    build(:svip_date_right, customer_group: group, preferences: preferences)
  end

  it 'is a double-points day until an operator says otherwise' do
    right = day({})

    expect(right).to be_valid
    expect(right.multiplier).to eq(2)
    expect(right.preferred_weekday).to eq('sunday')
  end

  # A member day worth 1 or less is a day that changes nothing, and the ledger
  # neutralises a non-positive multiplier — so the reader floors it rather than
  # paying a rate nobody agreed to.
  it 'never pays less than the ordinary rate' do
    expect(day(multiplier: 1).multiplier).to eq(1)
    expect(day(multiplier: 0).multiplier).to eq(1)
  end

  # The weekday is what the whole feature keys on: a day nothing matches is a
  # member day that never comes, and the operator would be waiting for it.
  it 'refuses a weekday that is not a day of the week' do
    expect(day(weekday: 'funday')).not_to be_valid
  end

  it 'accepts the weekday however it is written' do
    expect(day(weekday: 'Wednesday')).to be_valid
  end

  # A row written past the model — a console, an import — declares no day, and
  # nothing prints or matches one it does not declare.
  it 'answers no weekday for one nobody declares' do
    right = day({})
    right.preferences = { weekday: 'funday' }

    expect(right.weekday).to be_nil
    expect(right.day?(Date.new(2026, 9, 23))).to be(false)
  end

  # A threshold nobody can clear and a red packet worth less than nothing are
  # operator errors, refused where they are written.
  it 'refuses a threshold that is not a price' do
    expect(day(minimum_amount: 0)).not_to be_valid
    expect(day(minimum_amount: -10)).not_to be_valid
  end

  it 'refuses a red packet that is not a price' do
    expect(day(rights_red_money: 0)).not_to be_valid
  end

  it 'answers no threshold and no red packet for one that was left unset' do
    right = day({})

    expect(right.minimum_amount).to be_nil
    expect(right.red_money).to be_nil
    expect(right.qualifying_kinds).to eq([])
  end

  it 'reads the threshold and the red packet as money' do
    right = day(minimum_amount: '199.50', rights_red_money: '20')

    expect(right.minimum_amount).to eq(BigDecimal('199.5'))
    expect(right.red_money).to eq(BigDecimal('20'))
  end

  describe '#day?' do
    let(:wednesday) { Date.new(2026, 9, 23) }

    it 'is the weekday it declares, and no other' do
      right = day(weekday: 'wednesday')

      expect(right.day?(wednesday)).to be(true)
      expect(right.day?(wednesday + 1)).to be(false)
    end

    it 'has no day when it is asked about none' do
      expect(day(weekday: 'wednesday').day?(nil)).to be(false)
    end
  end

  describe '#order_multiplier' do
    let(:wednesday) { Date.new(2026, 9, 23) }
    let(:customer) { create(:customer) }
    let(:order) { build(:order, store: store, total: 300) }
    let(:right) { day(weekday: 'wednesday', multiplier: 3, minimum_amount: 199) }

    it 'pays the day’s rate on the day, for a basket over the threshold' do
      expect(right.order_multiplier(customer: customer, on: wednesday, order: order)).to eq(3)
    end

    # The morning’s qualifying basket is the point of the threshold: the day is
    # not a discount, it is a target.
    it 'pays the ordinary rate under the threshold' do
      small = build(:order, store: store, total: 99)

      expect(right.order_multiplier(customer: customer, on: wednesday, order: small)).to eq(1)
    end

    # 满199 includes 199: the threshold is what the basket has to reach, not what
    # it has to pass.
    it 'pays on a basket that is exactly the threshold' do
      exact = build(:order, store: store, total: 199)

      expect(right.order_multiplier(customer: customer, on: wednesday, order: exact)).to eq(3)
    end

    it 'pays nothing on any other day' do
      expect(right.order_multiplier(customer: customer, on: wednesday + 1, order: order)).to eq(1)
    end
  end

  # The question a reader with no basket asks: the day is the date's whatever the
  # basket would have been, which is what a page saying "today is the day" means.
  describe '#applies_on?' do
    let(:wednesday) { Date.new(2026, 9, 23) }

    it 'is the day it declares' do
      right = day(weekday: 'wednesday')

      expect(right.applies_on?(customer: create(:customer), on: wednesday)).to be(true)
      expect(right.applies_on?(customer: create(:customer), on: wednesday + 1)).to be(false)
    end
  end

  describe '.for_customer' do
    let(:customer) { create(:customer) }

    it 'answers nothing for a customer in no tier' do
      create(:svip_date_right, customer_group: group, published: true)

      expect(described_class.for_customer(customer, store: store)).to be_nil
    end

    it 'answers nothing for a tier whose day nobody declared' do
      group.add_customers([customer.id])
      create(:member_price_right, customer_group: group, published: true)

      expect(described_class.for_customer(customer, store: store)).to be_nil
    end

    it 'answers the day of the tier the customer holds' do
      group.add_customers([customer.id])
      create(:svip_date_right, customer_group: group, published: true,
                               preferences: { weekday: 'wednesday', multiplier: 3 })

      day = described_class.for_customer(customer, store: store)

      expect(day).to be_a(Spree::Memberships::MemberDay)
      expect(day.times).to eq(3)
    end

    # A draft is a day nobody has been promised, and the same rule the member
    # centre reads: what a right has not published is not shown.
    it 'answers nothing for a day an operator has not published' do
      group.add_customers([customer.id])
      create(:svip_date_right, customer_group: group, published: false)

      expect(described_class.for_customer(customer, store: store)).to be_nil
    end
  end
end
