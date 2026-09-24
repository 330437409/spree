require 'spec_helper'

RSpec.describe Spree::MembershipRights::GiveGift, type: :model do
  let(:store) { @default_store }
  let(:group) { create(:customer_group, store: store) }
  let(:promotion) { create(:promotion, store: store) }

  def gift(preferences)
    build(:give_gift_right, customer_group: group, preferences: preferences)
  end

  it 'is a coupon gift of one claim a year until an operator says otherwise' do
    right = gift(gift_promotion_ids: [promotion.prefixed_id])

    expect(right).to be_valid
    expect(right).to be_coupon_gift
    expect(right.preferred_yearly_limit).to eq(1)
  end

  # A coupon gift nothing can be claimed from would report an allowance no claim
  # can spend, so it is refused where it is written.
  it 'refuses a coupon gift with no coupons' do
    expect(gift({})).not_to be_valid
  end

  it 'offers a coupon once however many times an operator lists it' do
    right = gift(gift_promotion_ids: [promotion.prefixed_id, promotion.prefixed_id])

    expect(right.gift_promotions).to eq([promotion])
  end

  # A delivered gift is not claimed here, so it answers nothing to read.
  it 'has no payload of its own when it is delivered' do
    right = gift(gift_mode: 'logistics')

    expect(right.member_payload(customer: nil, store: store)).to be_nil
  end

  it 'refuses an allowance nothing can be claimed against' do
    expect(gift(gift_promotion_ids: [promotion.prefixed_id], yearly_limit: 0)).not_to be_valid
  end

  it 'refuses a mode no claim understands' do
    expect(gift(gift_mode: 'raffle')).not_to be_valid
  end

  # A pool in another store is a code this tier must not draw.
  it 'refuses a coupon of another store' do
    elsewhere = create(:promotion, store: create(:store))

    expect(gift(gift_promotion_ids: [elsewhere.prefixed_id])).not_to be_valid
  end

  it 'refuses a coupon that never existed' do
    expect(gift(gift_promotion_ids: ['promo_nonexistent'])).not_to be_valid
  end

  it 'answers its coupons in the order the operator gave them' do
    second = create(:promotion, store: store)
    right = gift(gift_promotion_ids: [second.prefixed_id, promotion.prefixed_id])

    expect(right.gift_promotions).to eq([second, promotion])
  end
end
