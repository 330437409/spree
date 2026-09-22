require 'spec_helper'

RSpec.describe Spree::Coupons::Issue do
  let(:store) { @default_store }
  let(:promotion) { create(:coupon_wallet_promotion, store: store) }
  let(:customer) { create(:customer) }

  def issue(**overrides)
    described_class.call(
      { promotion: promotion, customer: customer, source: 'admin',
        idempotency_key: 'support:1', store: store }.merge(overrides)
    )
  end

  it 'hands over a code of the promotion and records what is owed' do
    result = issue

    expect(result).to be_success
    expect(result.value.coupon_code.promotion).to eq(promotion)
    expect(result.value.customer).to eq(customer)
    expect(result.value.grant).to be_usable
    expect(result.value.source).to eq('admin')
  end

  it 'answers the coupon the first call wrote when the same key arrives again' do
    first = issue
    second = issue

    expect(second.value).to eq(first.value)
    expect(Spree::CouponHolding.count).to eq(1)
    expect(Spree::Grant.where(kind: 'coupon_holding').count).to eq(1)
  end

  it 'refuses without a key, because nothing else makes two issues one' do
    expect(issue(idempotency_key: nil)).to be_failure
  end

  it 'hands over a code nobody holds' do
    held = issue.value.coupon_code

    expect(issue(idempotency_key: 'support:2').value.coupon_code).not_to eq(held)
  end

  # A code that has been applied is out of the pool whether or not anybody
  # holds it: handing it over would put a coupon in a wallet that already reads
  # as spent, and the cart would refuse it at checkout.
  it 'never hands over a code that has been spent' do
    spent = promotion.coupon_codes.first
    spent.update!(state: 'used')

    handed = %w[support:2 support:3 support:4].map { |key| issue(idempotency_key: key).value.coupon_code }

    expect(handed).not_to include(spent)
  end

  # The primitive never hands a key back, so a coupon the store took away is
  # not minted again under the same key.
  it 'refuses a key whose coupon was taken back' do
    first = issue
    first.value.destroy

    result = issue

    expect(result).to be_failure
    expect(result.error.value).to eq(:coupon_already_recorded)
  end

  it 'mints a code when the promotion has none left to give' do
    promotion.coupon_codes.each { |code| code.update!(state: 'used') }
    promotion.coupon_codes.destroy_all

    result = issue

    expect(result).to be_success
    expect(promotion.reload.coupon_codes.count).to be >= 1
  end

  it 'can mint a coupon nobody holds yet' do
    result = issue(customer: nil, source: 'gift')

    expect(result.value.customer).to be_nil
    expect(result.value.grant.customer).to be_nil
  end
end
