require 'spec_helper'

RSpec.describe Spree::Memberships::MemberCentre, type: :model do
  let(:store) { @default_store }
  let(:group) { create(:customer_group, store: store) }
  let(:tier) { create(:membership_tier_setting, customer_group: group, rank: 1) }
  let(:customer) { create(:customer) }

  def centre(for_customer = customer)
    described_class.new(store: store, customer: for_customer)
  end

  it 'answers no tier for a customer who is in none' do
    expect(centre.tier).to be_nil
    expect(centre.rights_total).to eq(0)
    expect(centre.sections).to be_empty
  end

  it 'answers the tier the customer is in' do
    tier
    group.add_customers([customer.id])

    expect(centre.tier).to eq(tier)
  end

  # The flat list is the model and the sections are a projection of it: a kind
  # declares its panel, so nothing here enumerates one.
  # One writer keeps anybody on one tier; two is a setup error, and the honest
  # reading of it is the better tier rather than the one priced by accident.
  it 'answers the highest rung a customer holds' do
    tier
    higher_group = create(:customer_group, store: store)
    higher = create(:membership_tier_setting, customer_group: higher_group, rank: 9)
    group.add_customers([customer.id])
    higher_group.add_customers([customer.id])

    expect(centre.tier).to eq(higher)
  end

  it 'groups the store\'s rights by the panel their kind declares' do
    tier
    coupon = create(:coupon_right, customer_group: group)
    card = create(:member_price_right, customer_group: group)
    group.add_customers([customer.id])

    sections = centre.sections

    expect(sections.keys).to contain_exactly('vipCouponInfoVo')
    expect(sections['vipCouponInfoVo']).to contain_exactly(coupon)
    expect(card.class.presents_as).to be_nil
  end

  it 'counts what the customer\'s own tier carries, not the whole ladder' do
    tier
    create(:membership_right, customer_group: group)
    other_group = create(:customer_group, store: store)
    create(:membership_tier_setting, customer_group: other_group, rank: 2)
    create(:membership_right, customer_group: other_group)
    group.add_customers([customer.id])

    expect(centre.rights.size).to eq(2)
    expect(centre.rights_total).to eq(1)
  end

  it 'marks the entries on the customer\'s own rung' do
    tier
    mine = create(:membership_right, customer_group: group)
    other_group = create(:customer_group, store: store)
    create(:membership_tier_setting, customer_group: other_group, rank: 2)
    theirs = create(:membership_right, customer_group: other_group)
    group.add_customers([customer.id])

    expect(centre.holds?(mine)).to be(true)
    expect(centre.holds?(theirs)).to be(false)
  end

  # A right of another store's tier is not this store's business.
  it 'reads only this store\'s ladder' do
    tier
    create(:membership_right, customer_group: group)
    elsewhere = create(:customer_group, store: create(:store))
    create(:membership_tier_setting, customer_group: elsewhere)
    create(:membership_right, customer_group: elsewhere)

    expect(centre.rights.map(&:customer_group_id)).to all(eq(group.id))
  end

  describe 'the birthday it reports' do
    let(:customer) { create(:customer, birthday: Date.new(1990, 5, 20)) }

    it 'answers nothing when no birthday is set' do
      customer.update!(birthday: nil)

      expect(centre.birthday).to be_nil
    end

    # The client's 距离您生日还有 N 天, and the multiplier its 去点单 branch leads to.
    it 'answers how far away it is, and what the tier grants for it' do
      tier
      Spree::Memberships::AssignTier.call(customer: customer, customer_group: group)
      create(:birthday_right, customer_group: group, published: true, preferences: { multiplier: 3 })

      Timecop.freeze(Time.zone.local(2026, 5, 17, 10)) do
        expect(centre.birthday).to eq('on' => '1990-05-20', 'days_away' => 3, 'multiplier' => 3)
      end

      Timecop.freeze(Time.zone.local(2026, 5, 20, 10)) do
        expect(centre.birthday).to include('days_away' => 0)
      end
    end

    # Other kinds apply on dates too — a member day is a weekday, and this
    # customer's birthday is a Wednesday — so the rate reported here is the
    # birthday's rather than whichever right the date happens to suit.
    it 'answers the birthday’s own rate when the tier’s day falls on it too' do
      tier
      Spree::Memberships::AssignTier.call(customer: customer, customer_group: group)
      create(:birthday_right, customer_group: group, published: true, preferences: { multiplier: 3 })
      create(:svip_date_right, customer_group: group, published: true,
                               preferences: { weekday: 'wednesday', multiplier: 5 })

      Timecop.freeze(Time.zone.local(2026, 5, 20, 10)) do
        expect(centre.birthday).to include('multiplier' => 3)
      end
    end

    # A day the tier runs is not a birthday the tier grants: the countdown is the
    # birthday's, and a tier carrying no birthday right grants none.
    it 'answers no rate for a tier that grants no birthday' do
      tier
      Spree::Memberships::AssignTier.call(customer: customer, customer_group: group)
      create(:svip_date_right, customer_group: group, published: true,
                               preferences: { weekday: 'wednesday', multiplier: 5 })

      Timecop.freeze(Time.zone.local(2026, 5, 20, 10)) do
        expect(centre.birthday).to include('multiplier' => nil)
      end
    end

    # A draft grants nothing yet, so its rate is nobody's promise: the multiplier
    # the ledger pays by is folded over published rights alone.
    it 'answers no rate for a birthday right an operator has not published' do
      tier
      Spree::Memberships::AssignTier.call(customer: customer, customer_group: group)
      create(:birthday_right, customer_group: group, published: false, preferences: { multiplier: 4 })

      Timecop.freeze(Time.zone.local(2026, 5, 20, 10)) do
        expect(centre.birthday).to include('multiplier' => nil)
      end
    end
  end

end
