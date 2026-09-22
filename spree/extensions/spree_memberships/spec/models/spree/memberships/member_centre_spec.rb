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
end
