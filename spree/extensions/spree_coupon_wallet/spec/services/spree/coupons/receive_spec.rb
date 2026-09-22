require 'spec_helper'

RSpec.describe Spree::Coupons::Receive do
  let(:store) { @default_store }
  let(:promotion) { create(:coupon_wallet_promotion, store: store) }
  let(:customer) { create(:customer) }
  let(:code) { promotion.coupon_codes.first.code }

  # `self.` reads the example's own code and customer: a bare name in a default
  # is the parameter being defined, not the `let`.
  def receive(code: self.code, customer: self.customer)
    described_class.call(code: code, customer: customer, store: store)
  end

  it 'claims a code the customer was sent into their wallet' do
    result = receive

    expect(result).to be_success
    expect(result.value.coupon_code.code).to eq(code)
    expect(result.value.customer).to eq(customer)
    expect(result.value.source).to eq('sms')
  end

  it 'ignores the case and the spaces a customer types' do
    expect(receive(code: "  #{code.upcase} ")).to be_success
  end

  it 'answers the same coupon when the code arrives twice' do
    first = receive
    second = receive

    expect(second.value).to eq(first.value)
    expect(Spree::CouponHolding.count).to eq(1)
  end

  it 'refuses a code nobody issued' do
    expect(receive(code: 'nope-0000')).to be_failure
  end

  it 'refuses a code somebody else already holds' do
    receive
    other = create(:customer)

    expect(receive(customer: other)).to be_failure
  end

  # A code a promotion minted for wholesale use is the promotion's own, and a
  # customer holding it would be holding something they were never given.
  it 'refuses a code a cart has already taken' do
    Spree::CouponCode.find_by(code: code).update!(cart: create(:cart, store: store))

    expect(receive).to be_failure
  end

  it 'gives a drawn coupon that nobody holds yet its holder' do
    drawn = Spree::Coupons::Issue.call(promotion: promotion, source: 'gift', store: store,
                                       idempotency_key: 'gift:1').value
    expect(drawn.customer).to be_nil

    result = receive(code: drawn.coupon_code.code)

    expect(result).to be_success
    # The answer is the wallet's own shape, not the grant the claim writes.
    expect(result.value).to eq(drawn)
    expect(drawn.reload.customer).to eq(customer)
    expect(Spree::CouponHolding.count).to eq(1)
  end

  # Codes are unique across the platform, so an unscoped lookup would let a
  # shopper here claim a coupon that belongs to another store's promotion.
  it 'refuses a code that belongs to another store' do
    elsewhere = create(:coupon_wallet_promotion, store: create(:store))

    result = receive(code: elsewhere.coupon_codes.first.code)

    expect(result).to be_failure
    expect(result.error.value).to eq(:coupon_code_not_found)
  end

  # The store is the request's own when a caller names none, as it is for the
  # service that hands coupons out.
  it 'claims a code without being told the store' do
    result = described_class.call(code: code, customer: customer)

    expect(result).to be_success
    expect(result.value).to be_a(Spree::CouponHolding)
  end

  it 'refuses a coupon the store has taken back, in its own words' do
    held = receive.value
    held.destroy

    result = receive

    expect(result).to be_failure
    expect(result.error.value).to eq(:coupon_no_longer_available)
  end

  it 'refuses a coupon that lapsed before anybody claimed it, in its own words' do
    drawn = Spree::Coupons::Issue.call(promotion: promotion, source: 'gift', store: store,
                                       idempotency_key: 'spec:lapsed', expires_at: 1.day.ago).value

    result = receive(code: drawn.coupon_code.code)

    expect(result).to be_failure
    expect(result.error.value).to eq(:coupon_no_longer_available)
  end
end
