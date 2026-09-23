require 'spec_helper'

# TEMPORARY PROBE — delete before finishing.
RSpec.describe 'probe: birthday multiplier and read' do
  let(:store) { @default_store }

  def tier_for(group, rank: 1)
    create(:membership_tier_setting, customer_group: group, rank: rank, validity_days: 365)
  end

  it 'probes the leap-day pair' do
    birthday = Date.new(1992, 2, 29)
    customer = create(:customer, birthday: birthday)
    group = create(:customer_group, store: store)
    tier_for(group)
    Spree::Memberships::AssignTier.call(customer: customer, customer_group: group)
    create(:birthday_right, customer_group: group, published: true, preferences: { multiplier: 3 })
    centre = Spree::Memberships::MemberCentre.new(store: store, customer: customer)
    order = create(:order, store: store, customer: customer)

    [Date.new(2027, 2, 27), Date.new(2027, 2, 28), Date.new(2027, 3, 1),
     Date.new(2028, 2, 28), Date.new(2028, 2, 29), Date.new(2028, 3, 1),
     Date.new(2026, 12, 31), Date.new(2027, 1, 1)].each do |day|
      Timecop.freeze(Time.zone.local(day.year, day.month, day.day, 10)) do
        puts "LEAP #{day} days_away=#{centre.days_away(birthday).inspect} " \
             "read=#{centre.birthday.inspect} " \
             "service=#{Spree::Memberships::PointsMultiplier.call(order: order).value.inspect}"
      end
    end
  end

  it 'probes the store calendar against the server calendar' do
    store.update!(preferred_timezone: 'Asia/Shanghai')
    customer = create(:customer, birthday: Date.new(1990, 5, 20))
    group = create(:customer_group, store: store)
    tier_for(group)
    Spree::Memberships::AssignTier.call(customer: customer, customer_group: group)
    create(:birthday_right, customer_group: group, published: true, preferences: { multiplier: 3 })
    order = create(:order, store: store, customer: customer)
    centre = Spree::Memberships::MemberCentre.new(store: store, customer: customer)

    # 2026-05-19 17:00 UTC is 2026-05-20 01:00 in Shanghai.
    Timecop.freeze(Time.utc(2026, 5, 19, 17, 0)) do
      puts "TZ store=#{store.preferred_timezone} utc=#{Time.current.utc} " \
           "service=#{Spree::Memberships::PointsMultiplier.call(order: order).value.inspect} " \
           "days_away=#{centre.days_away(Date.new(1990, 5, 20)).inspect}"
    end
    Timecop.freeze(Time.utc(2026, 5, 20, 17, 0)) do
      puts "TZ next-day(Shanghai 5/21) service=#{Spree::Memberships::PointsMultiplier.call(order: order).value.inspect} " \
           "days_away=#{centre.days_away(Date.new(1990, 5, 20)).inspect}"
    end
  end

  it 'probes another store tier and a store with an unknown zone' do
    elsewhere = create(:store)
    other_group = create(:customer_group, store: elsewhere)
    tier_for(other_group)
    customer = create(:customer, birthday: Date.new(1990, 5, 20))
    Spree::Memberships::AssignTier.call(customer: customer, customer_group: other_group)
    create(:birthday_right, customer_group: other_group, published: true, preferences: { multiplier: 3 })
    order = create(:order, store: store, customer: customer)
    centre = Spree::Memberships::MemberCentre.new(store: store, customer: customer)

    Timecop.freeze(Time.zone.local(2026, 5, 20, 10)) do
      puts "CROSSSTORE service=#{Spree::Memberships::PointsMultiplier.call(order: order).value.inspect} " \
           "read=#{centre.birthday.inspect}"
    end

    store.update_columns(preferences: store.preferences.merge(timezone: 'Nowhere/Zone'))
    Timecop.freeze(Time.zone.local(2026, 5, 20, 10)) do
      puts "BADZONE read=#{Spree::Memberships::MemberCentre.new(store: store.reload, customer: customer).birthday.inspect}"
    end
  end

  it 'probes the multiplier kinds and strings' do
    customer = create(:customer, birthday: Date.new(1990, 5, 20))
    group = create(:customer_group, store: store)
    tier_for(group)
    Spree::Memberships::AssignTier.call(customer: customer, customer_group: group)
    order = create(:order, store: store, customer: customer)
    centre = Spree::Memberships::MemberCentre.new(store: store, customer: customer)

    [0, -2, 1, 5, '3', 2.7].each do |value|
      Spree::MembershipRight.where(customer_group_id: group.id).delete_all
      right = create(:birthday_right, customer_group: group, published: true, preferences: { multiplier: value })
      Timecop.freeze(Time.zone.local(2026, 5, 20, 10)) do
        puts "MULT #{value.inspect}(#{value.class}) stored=#{right.reload.multiplier.inspect} " \
             "service=#{Spree::Memberships::PointsMultiplier.call(order: order).value.inspect} " \
             "earning=#{Spree::Points::Earning.call(order: order).value.inspect} " \
             "read=#{centre.birthday['multiplier'].inspect} sections=#{centre.sections.values.flatten.size}"
      end
    end
  end

  it 'probes the unpublished right in the read' do
    customer = create(:customer, birthday: Date.new(1990, 5, 20))
    group = create(:customer_group, store: store)
    tier_for(group)
    Spree::Memberships::AssignTier.call(customer: customer, customer_group: group)
    create(:birthday_right, customer_group: group, published: false, preferences: { multiplier: 3 })
    centre = Spree::Memberships::MemberCentre.new(store: store, customer: customer)

    Timecop.freeze(Time.zone.local(2026, 5, 20, 10)) do
      puts "UNPUBLISHED read=#{centre.birthday.inspect} rights=#{centre.rights.size} sections=#{centre.sections.keys.inspect}"
    end
  end

  it 'probes the string birthday and no-customer order' do
    customer = Spree::Customer.new(birthday: '1990-05-20')
    puts "STRINGCAST class=#{customer.birthday.class} value=#{customer.birthday.inspect}"
    customer2 = Spree::Customer.new
    customer2.birthday = 'nonsense'
    puts "STRINGCAST bad=#{customer2.birthday.inspect}"

    guest_order = create(:order, store: store, customer: nil)
    puts "GUESTORDER service=#{Spree::Memberships::PointsMultiplier.call(order: guest_order).value.inspect}"
  end
end

RSpec.describe 'probe: registration order' do
  it 'shows where to_prepare runs against config initializers' do
    names = Rails.application.initializers.map(&:name)
    puts "ORDER load_config_initializers=#{names.index(:load_config_initializers)} run_prepare_callbacks=#{names.index(:run_prepare_callbacks)} total=#{names.size}"
    puts "ORDER resolved=#{Spree::Dependencies.points_multiplier_service.inspect}"
    puts "ORDER overrides=#{Spree::Dependencies.overrides[:points_multiplier_service].inspect}"
  end
end
