require 'spec_helper'

RSpec.describe Spree::Memberships::ClaimYearGift do
  let(:store) { @default_store }
  let(:customer) { create(:customer) }
  let(:group) { create(:customer_group, store: store) }
  let!(:tier) { create(:membership_tier_setting, customer_group: group, rank: 1, validity_days: 365) }
  let(:first_coupon) { create(:promotion, store: store, name: 'The first') }
  let(:second_coupon) { create(:promotion, store: store, name: 'The second') }

  let(:right) do
    create(:give_gift_right, customer_group: group, preferences: {
      gift_promotion_ids: [first_coupon.prefixed_id, second_coupon.prefixed_id]
    }.merge(preferences))
  end
  let(:preferences) { {} }

  before { group.add_customers([customer.id]) }

  def claim(promotion_id: nil)
    described_class.call(right: right, customer: customer, promotion_id: promotion_id, store: store)
  end

  # A holding's owner is on the grant it was issued under, not on the holding.
  def holdings
    Spree::CouponHolding.joins(:grant).where(spree_grants: { customer_id: customer.id })
  end

  it 'hands over the gift’s first coupon' do
    result = claim

    expect(result).to be_success
    expect(result.value.coupon_code.promotion).to eq(first_coupon)
    expect(result.value.code).to be_present
  end

  # The claim names the tier rather than the right row, so an operator replacing
  # the gift does not hand the year's allowance back.
  it 'records the claim as a consumed grant that names the coupon it released' do
    result = claim

    row = Spree::Grant.find_by(kind: 'year_gift_claim', customer_id: customer.id)
    expect(row).to be_consumed
    expect(row.source).to eq(group)
    expect(row.metadata['promotion_id']).to eq(first_coupon.id.to_s)
    expect(row.issued).to eq(result.value)
  end

  # The documented way to change a gift: retire the right, write its replacement.
  # The year is the tier's, so the replacement starts with the allowance already
  # spent.
  it 'keeps the year spent when the gift is replaced' do
    claim
    right.destroy
    replacement = create(:give_gift_right, customer_group: group, preferences: {
      gift_promotion_ids: [second_coupon.prefixed_id]
    })

    result = described_class.call(right: replacement, customer: customer, store: store)

    expect(result).to be_failure
    expect(result.error.to_s).to eq(Spree.t('memberships.errors.gift_allowance_spent'))
    expect(holdings.count).to eq(1)
  end

  # An allowance is spent one claim at a time, and the coupons come in the order
  # the operator gave them.
  context 'when the tier allows two claims a year' do
    let(:preferences) { { yearly_limit: 2 } }

    it 'takes the next coupon on a later claim' do
      claim

      expect(claim.value.coupon_code.promotion).to eq(second_coupon)
    end

    it 'refuses a claim for every coupon already taken' do
      claim
      claim

      result = claim

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('memberships.errors.gift_claimed'))
    end
  end

  it 'takes the coupon the member picked' do
    result = claim(promotion_id: second_coupon.prefixed_id)

    expect(result).to be_success
    expect(result.value.coupon_code.promotion).to eq(second_coupon)
  end

  it 'refuses a claim past the year’s allowance' do
    claim

    result = claim

    expect(result).to be_failure
    expect(result.error.to_s).to eq(Spree.t('memberships.errors.gift_allowance_spent'))
  end

  # A claim is one member taking one coupon, so a request retried — a double
  # tap, a client resending after a timeout — is answered the coupon the first
  # call issued rather than taking a second one out of the pool. What makes it
  # the same claim is the coupon it names: a repeat that names none is asking
  # for whatever is next, and the allowance answers that.
  it 'answers the same coupon to a claim retried' do
    first = claim(promotion_id: first_coupon.prefixed_id)
    retried = claim(promotion_id: first_coupon.prefixed_id)

    expect(retried).to be_success
    expect(retried.value).to eq(first.value)
    expect(holdings.count).to eq(1)
  end

  it 'refuses a coupon that is not one of the gift’s' do
    result = claim(promotion_id: create(:promotion, store: store).prefixed_id)

    expect(result).to be_failure
    expect(result.error.to_s).to eq(Spree.t('memberships.errors.gift_coupon_unknown'))
  end

  it 'refuses a member of another tier' do
    right
    group.remove_customers([customer.id])

    expect(claim).to be_failure
  end

  it 'refuses a right that is not a gift' do
    result = described_class.call(right: create(:coupon_right, customer_group: group),
                                  customer: customer, store: store)

    expect(result).to be_failure
    expect(holdings.count).to eq(0)
  end

  # The gift's other mode is a physical one, claimed in the frame this plan
  # excludes: the right is here, the claim is not.
  it 'refuses a gift that is delivered rather than handed over' do
    right.update!(preferences: { gift_mode: 'logistics' })

    result = claim

    expect(result).to be_failure
    expect(result.error.to_s).to eq(Spree.t('memberships.errors.gift_not_coupons'))
  end

  # The year is the store's own, so a gift claimed in a year that has passed
  # leaves the new year's allowance whole.
  it 'hands over a coupon again in the next year' do
    Timecop.travel(1.year.ago) { expect(claim).to be_success }

    claim

    expect(holdings.count).to eq(2)
  end
end
