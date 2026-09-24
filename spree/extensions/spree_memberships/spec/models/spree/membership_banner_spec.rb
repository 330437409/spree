require 'spec_helper'

RSpec.describe Spree::MembershipBanner, type: :model do
  let(:store) { @default_store }
  let(:group) { create(:customer_group, store: store) }
  let!(:tier) { create(:membership_tier_setting, customer_group: group) }
  let(:customer) { create(:customer) }

  def banner(**attributes)
    build(:membership_banner, customer_group: group, **attributes)
  end

  it 'needs a picture: a banner with none is nothing to show' do
    expect(banner(pic: nil)).not_to be_valid
  end

  # One banner per tier, among live rows — the shape a tier's settings row has.
  it 'holds one banner per tier' do
    banner.save!

    expect(banner).not_to be_valid
  end

  # An area the client cannot place is a tap target nobody can tap: it carries
  # the style it is positioned by and the link it opens, and nothing else.
  it 'refuses an area that could not be placed' do
    expect(banner(areas: [{ 'link' => '/pages/member/index' }])).not_to be_valid
    expect(banner(areas: [{ 'area_rem' => 'left: 1rem;', 'link' => '/a', 'unknown' => 1 }])).not_to be_valid
    expect(banner(areas: [{ 'area_rem' => 'left: 1rem;', 'link' => '/a' }])).to be_valid
  end

  it 'resolves the banner of the customer’s own tier' do
    row = banner(name: '会员中心')
    row.save!
    group.add_customers([customer.id])

    expect(described_class.for_customer(customer, store: store)).to eq(row)
  end

  it 'answers nothing for a customer in no tier' do
    banner.save!

    expect(described_class.for_customer(customer, store: store)).to be_nil
  end
end
