require 'spec_helper'

RSpec.describe Spree::Memberships::YearGift, type: :model do
  let(:store) { @default_store }
  let(:customer) { create(:customer) }
  let(:group) { create(:customer_group, store: store) }
  let!(:tier) { create(:membership_tier_setting, customer_group: group, rank: 1) }
  let(:first_coupon) { create(:promotion, store: store, name: 'The first') }
  let(:second_coupon) { create(:promotion, store: store, name: 'The second') }
  let(:yearly_limit) { 2 }

  let(:right) do
    create(:give_gift_right, customer_group: group, preferences: {
      gift_promotion_ids: [first_coupon.prefixed_id, second_coupon.prefixed_id],
      yearly_limit: yearly_limit
    })
  end

  before { group.add_customers([customer.id]) }

  def gift
    described_class.new(right: right, customer: customer, store: store)
  end

  def claim(promotion)
    Spree::Memberships::ClaimYearGift.call(right: right, customer: customer,
                                           promotion_id: promotion&.prefixed_id, store: store)
  end

  it 'counts the year’s allowance and the coupons the gift still holds' do
    expect(gift.can_count).to eq(2)
    expect(gift.usable_num).to eq(2)
  end

  it 'marks the coupons this member has already taken' do
    claim(first_coupon)

    expect(gift.coupons.map { |coupon| [coupon.promotion, coupon.claimed?] }).
      to eq([[first_coupon, true], [second_coupon, false]])
  end

  # The two numbers disagree on purpose, and that is the state the client reads
  # 领取完毕 in: everything the year allows has been taken while coupons remain.
  context 'when the tier allows one claim a year' do
    let(:yearly_limit) { 1 }

    it 'counts the allowance spent while coupons remain' do
      claim(first_coupon)

      expect(gift.can_count).to eq(0)
      expect(gift.usable_num).to eq(1)
    end
  end

  it 'answers the coupon a claim would take next' do
    claim(first_coupon)

    expect(gift.next_coupon.promotion).to eq(second_coupon)
  end

  it 'holds no coupon for a promotion that is not the gift’s' do
    expect(gift.coupon_for(create(:promotion, store: store).prefixed_id)).to be_nil
  end

  # A claim taken last year is last year's: the allowance is counted in the
  # store's own calendar, and the gift is offered again.
  it 'counts nothing taken last year' do
    Timecop.travel(1.year.ago) { claim(first_coupon) }

    expect(gift.can_count).to eq(2)
    expect(gift.usable_num).to eq(2)
    expect(gift.coupons.first.claimed?).to be(false)
  end
end
