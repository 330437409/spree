require 'spec_helper'

RSpec.describe Spree::Coupons::DrawCoupon do
  let(:store) { @default_store }
  let(:campaign) { create(:coupon_campaign, store: store) }
  let(:customer) { create(:customer) }

  # `self.` reads the example's own campaign: a bare `campaign` in a default
  # is the parameter being defined, not the `let`.
  def draw(campaign: self.campaign, customer: self.customer)
    described_class.call(campaign: campaign, customer: customer, store: store)
  end

  it 'hands the customer a coupon of the campaign’s promotion' do
    result = draw

    expect(result).to be_success
    expect(result.value.customer).to eq(customer)
    expect(result.value.campaign).to eq(campaign)
    expect(result.value.source).to eq('draw')
  end

  # One tap is one coupon: two requests that arrive together build the same
  # key, so the second is answered with the first's coupon rather than minting
  # a second one.
  it 'counts a draw once however many rows it has taken' do
    expect { draw }.to change { Spree::CouponHolding.for_campaign(campaign).count }.by(1)
    expect(draw).to be_failure
    expect(Spree::CouponHolding.for_campaign(campaign).count).to eq(1)
  end

  it 'hands a second coupon when the campaign allows more than one' do
    campaign.preferred_limit_per_customer = 2

    first = draw
    second = draw

    expect(second).to be_success
    expect(second.value.coupon_code).not_to eq(first.value.coupon_code)
  end

  it 'refuses a campaign that is not running' do
    campaign.update!(status: 'paused')

    expect(draw).to be_failure
  end

  it 'refuses once the customer has taken what the campaign allows' do
    campaign.preferred_limit_per_customer = 2

    expect(draw).to be_success
    expect(draw).to be_success
    expect(draw).to be_failure
    expect(Spree::CouponHolding.for_campaign(campaign).count).to eq(2)
  end

  it 'refuses a customer the campaign does not admit' do
    settled = create(:new_customer_coupon_campaign, store: store)

    expect(draw(campaign: settled, customer: create(:customer, created_at: 90.days.ago))).to be_failure
    expect(draw(campaign: settled, customer: create(:customer, created_at: 2.days.ago))).to be_success
  end

  it 'gives the coupon the campaign’s own life' do
    campaign.preferred_valid_for_days = 7

    expect(draw.value.expires_at).to be_within(1.minute).of(7.days.from_now)
  end
end
