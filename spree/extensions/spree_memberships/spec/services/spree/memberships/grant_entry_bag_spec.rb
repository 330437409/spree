require 'spec_helper'

RSpec.describe Spree::Memberships::GrantEntryBag do
  let(:store) { @default_store }
  let(:customer) { create(:customer) }
  let(:group) { create(:customer_group, store: store) }
  let!(:tier) { create(:membership_tier_setting, customer_group: group, rank: 1, validity_days: 365) }
  let(:promotion) { create(:promotion, store: store) }

  def points_right(amount)
    create(:entry_integral_right, customer_group: group, preferences: { amount: amount })
  end

  def coupon_right(promotion_id)
    create(:coupon_right, customer_group: group, preferences: { promotion_id: promotion_id })
  end

  # A holding's owner is on the grant it was issued under, not on the holding.
  def holdings
    Spree::CouponHolding.joins(:grant).where(spree_grants: { customer_id: customer.id })
  end

  def activate(card)
    Spree::MembershipCards::Activate.call(card: card, customer: customer)
  end

  it 'credits the tier’s points and draws its coupon when the card is activated' do
    points_right(100)
    coupon_right(promotion.prefixed_id)
    card = create(:membership_card, customer: customer, customer_group: group)

    expect(activate(card)).to be_success

    account = Spree::PointAccount.for(store: store, customer: customer, kind: Spree::PointAccount::POINTS)
    expect(account.balance).to eq(100)
    expect(holdings.count).to eq(1)
  end

  # The card is activated once, but the bag is asked for by key — a retried
  # activation, or an operator running it again, hands over nothing twice.
  it 'hands over nothing twice for one card' do
    points_right(100)
    card = create(:membership_card, customer: customer, customer_group: group)
    activate(card)

    Spree::Memberships::GrantEntryBag.call(source: card, customer: customer,
                                            rights: Spree::MembershipRight.all)

    account = Spree::PointAccount.for(store: store, customer: customer, kind: Spree::PointAccount::POINTS)
    expect(account.balance).to eq(100)
  end

  it 'hands over nothing for a right an operator has not filled in' do
    points_right(0)
    create(:coupon_right, customer_group: group)
    card = create(:membership_card, customer: customer, customer_group: group)

    expect(activate(card)).to be_success
    expect(Spree::PointAccount.for(store: store, customer: customer, kind: Spree::PointAccount::POINTS).balance).to eq(0)
    expect(holdings.count).to eq(0)
  end

  # The promotion is checked where the operator writes it, so this is the seam a
  # right written before that check existed still reaches.
  it 'refuses a coupon whose promotion is gone' do
    right = coupon_right(promotion.prefixed_id)
    right.update_column(:preferences, { promotion_id: 'prom_missing' })
    card = create(:membership_card, customer: customer, customer_group: group)

    result = Spree::Memberships::GrantEntryBag.call(source: card, customer: customer,
                                                    rights: Spree::MembershipRight.where(id: right.id))

    expect(result).to be_failure
    expect(holdings.count).to eq(0)
  end

  it 'refuses a coupon right naming a promotion that never existed' do
    expect(build(:coupon_right, customer_group: group,
                                preferences: { promotion_id: 'prom_nonexistent' })).not_to be_valid
  end
end
