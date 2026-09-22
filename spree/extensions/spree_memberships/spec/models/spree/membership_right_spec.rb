require 'spec_helper'

RSpec.describe Spree::MembershipRight, type: :model do
  let(:store) { @default_store }
  let(:group) { create(:customer_group, store: store) }
  let(:right) { create(:membership_right, customer_group: group) }

  it 'registers its kinds, each named by its api_type' do
    expect(SpreeMemberships.membership_rights.map(&:api_type)).to contain_exactly(
      'member_price', 'exclusive_coupon', 'coupon', 'large_coupon', 'add_bag',
      'priority_distribution', 'birthday_double_integral', 'give_gift',
      'surprise_red_envelope', 'svip_date'
    )
    expect(described_class.find_by_api_type('birthday_double_integral')).
      to eq(Spree::MembershipRights::BirthdayDoubleIntegral)
  end

  it 'refuses a kind nothing registered' do
    right.type = 'Spree::MembershipRights::FreeShipping'

    expect(right).not_to be_valid
  end

  # One of each kind per tier, among live rows only: a replacement is saved
  # before the row it supersedes is retired.
  it 'carries one right of a kind per tier' do
    right

    expect(build(:membership_right, customer_group: group)).not_to be_valid

    right.destroy
    expect(build(:membership_right, customer_group: group)).to be_valid
  end

  it 'reaches its store through its tier' do
    expect(right.store).to eq(store)
  end

  # The panel is the kind's own declaration, so a kind a gem adds joins an
  # existing one with no change to any read.
  it 'declares the panel it presents in, and two kinds share one' do
    expect(Spree::MembershipRights::ExclusiveCoupon.presents_as).to eq('vipCouponInfoVo')
    expect(Spree::MembershipRights::Coupon.presents_as).to eq('vipCouponInfoVo')
    expect(Spree::MembershipRights::MemberPrice.presents_as).to be_nil
  end

  it 'shows its own name when the operator gave one, and the kind otherwise' do
    expect(right.display_name).to eq('Exclusive coupon')

    right.update!(name: '双十一专属券')
    expect(right.display_name).to eq('双十一专属券')
  end

  it 'carries the settings its kind declares' do
    birthday = Spree::MembershipRights::BirthdayDoubleIntegral.new

    expect(birthday.multiplier).to eq(2)
    birthday.preferred_multiplier = 3
    expect(birthday.multiplier).to eq(3)
  end
end
