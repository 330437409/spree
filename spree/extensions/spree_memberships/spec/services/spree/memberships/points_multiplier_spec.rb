require 'spec_helper'

RSpec.describe Spree::Memberships::PointsMultiplier do
  let(:store) { @default_store }
  let(:customer) { create(:customer, birthday: Date.new(1990, 5, 20)) }
  let(:group) { create(:customer_group, store: store) }
  let!(:tier) { create(:membership_tier_setting, customer_group: group, rank: 1, validity_days: 365) }
  let(:order) { create(:order, store: store, customer: customer) }

  def multiplier
    described_class.call(order: order).value
  end

  def in_tier!
    Spree::Memberships::AssignTier.call(customer: customer, customer_group: group)
  end

  def with_birthday_right(multiplier = 3)
    create(:birthday_right, customer_group: group, published: true, preferences: { multiplier: multiplier })
  end

  it 'multiplies nothing for a customer who is not in the tier' do
    create(:birthday_right, customer_group: group, published: true, preferences: { multiplier: 3 })

    expect(multiplier).to eq(1)
  end

  it 'multiplies nothing when the tier carries no birthday right' do
    in_tier!

    expect(multiplier).to eq(1)
  end

  it 'multiplies on the birthday itself, by what the right says' do
    in_tier!
    with_birthday_right(3)

    Timecop.freeze(Time.zone.local(2026, 5, 20, 10)) do
      expect(multiplier).to eq(3)
    end
  end

  it 'multiplies nothing on any other day' do
    in_tier!
    with_birthday_right(3)

    Timecop.freeze(Time.zone.local(2026, 5, 21, 10)) do
      expect(multiplier).to eq(1)
    end
  end

  # The day belongs to the store's calendar: a merchant in Shanghai is already on
  # the 20th at 17:00 UTC on the 19th, and the member's birthday must pay there.
  it 'reads the birthday in the store’s own timezone' do
    store.update!(preferred_timezone: 'Asia/Shanghai')
    customer.update!(birthday: Date.new(1990, 5, 20))
    in_tier!
    with_birthday_right(2)

    Timecop.freeze(Time.utc(2026, 5, 19, 17, 0)) do
      expect(multiplier).to eq(2)
    end

    Timecop.freeze(Time.utc(2026, 5, 19, 15, 0)) do
      expect(multiplier).to eq(1)
    end
  end

  # A 29 February birthday in a year that has none is celebrated on the 28th —
  # which is the day the member centre counts down to as well.
  it 'celebrates a leap-day birthday on the month’s last day' do
    customer.update!(birthday: Date.new(1992, 2, 29))
    in_tier!
    with_birthday_right(2)

    Timecop.freeze(Time.zone.local(2026, 2, 28, 10)) do
      expect(multiplier).to eq(2)
    end

    Timecop.freeze(Time.zone.local(2026, 3, 1, 10)) do
      expect(multiplier).to eq(1)
    end
  end

  it 'multiplies nothing for a customer with no birthday' do
    customer.update!(birthday: nil)
    in_tier!
    with_birthday_right(3)

    expect(multiplier).to eq(1)
  end

  it 'multiplies nothing for an unpublished right' do
    in_tier!
    create(:birthday_right, customer_group: group, published: false, preferences: { multiplier: 3 })

    Timecop.freeze(Time.zone.local(2026, 5, 20, 10)) do
      expect(multiplier).to eq(1)
    end
  end

  # The order's own earn goes through this: the seam the points plan left nil for
  # this gem, now pointing at it.
  it 'is what a paid order earns with, on the day' do
    in_tier!
    with_birthday_right(2)
    store.update!(preferences: store.preferences.merge(points_earn_rate: 100, points_minimum_order_amount: 0))
    paid = create(:order_with_line_items, store: store, customer: customer, line_items_count: 1)

    other_day = Timecop.freeze(Time.zone.local(2026, 5, 21, 10)) { Spree::Points::Earning.call(order: paid).value }
    on_the_day = Timecop.freeze(Time.zone.local(2026, 5, 20, 10)) { Spree::Points::Earning.call(order: paid).value }

    expect(other_day).to be_positive
    expect(on_the_day).to eq(other_day * 2)
  end
end
