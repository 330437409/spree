require 'spec_helper'

RSpec.describe Spree::CouponCampaign, type: :model do
  let(:store) { @default_store }
  let(:promotion) { create(:coupon_wallet_promotion, store: store) }

  it 'registers its kinds, each with a name an operator reads' do
    expect(SpreeCouponWallet.coupon_campaign_types.map(&:api_type)).
      to contain_exactly('draw', 'new_customer', 'site_scoped')
    expect(Spree::CouponCampaign.find_by_api_type('new_customer')).to eq(Spree::CouponCampaigns::NewCustomer)
    expect(Spree::CouponCampaigns::Draw.human_name).to eq('Draw')
  end

  it 'refuses a kind no registry holds' do
    campaign = build(:coupon_campaign, store: store, promotion: promotion)
    campaign.type = 'Spree::CouponCampaigns::Lottery'

    expect(campaign).not_to be_valid
    expect(campaign.errors[:type]).to be_present
  end

  # A customer holds a code, and only a promotion that issues codes has any.
  it 'refuses a promotion that issues no individual codes' do
    campaign = build(:coupon_campaign, store: store, promotion: create(:promotion, store: store))

    expect(campaign).not_to be_valid
    expect(campaign.errors[:promotion]).to be_present
  end

  it 'needs a name' do
    expect(build(:coupon_campaign, store: store, promotion: promotion, name: nil)).not_to be_valid
  end

  describe 'its window' do
    it 'is running once it is active and its start has passed' do
      expect(build(:coupon_campaign, store: store, promotion: promotion)).to be_running
    end

    it 'is not running before its start or after its end' do
      expect(build(:coupon_campaign, store: store, promotion: promotion, starts_at: 1.hour.from_now)).not_to be_running
      expect(build(:coupon_campaign, store: store, promotion: promotion, expires_at: 1.hour.ago)).not_to be_running
    end

    it 'is not running while it is a draft, however open its window is' do
      expect(build(:coupon_campaign, store: store, promotion: promotion, status: 'draft')).not_to be_running
    end
  end

  it 'hands over a coupon that lives as long as the campaign says' do
    campaign = build(:coupon_campaign, store: store, promotion: promotion)

    expect(campaign.expiry_for_grant).to be_nil

    campaign.preferred_valid_for_days = 7
    expect(campaign.expiry_for_grant).to be_within(1.minute).of(7.days.from_now)
  end

  describe 'what each kind admits' do
    it 'a draw admits anybody' do
      campaign = create(:coupon_campaign, store: store, promotion: promotion)

      expect(campaign.eligible_for?(create(:customer))).to be(true)
    end

    it 'a welcome coupon admits an account that is still new' do
      campaign = create(:new_customer_coupon_campaign, store: store, promotion: promotion)

      expect(campaign.eligible_for?(create(:customer, created_at: 3.days.ago))).to be(true)
      expect(campaign.eligible_for?(create(:customer, created_at: 90.days.ago))).to be(false)
    end

    it 'a welcome coupon admits nobody once its own window is shorter' do
      campaign = create(:new_customer_coupon_campaign, store: store, promotion: promotion)
      campaign.preferred_within_days = 1

      expect(campaign.eligible_for?(create(:customer, created_at: 3.days.ago))).to be(false)
    end

    it 'a site-scoped campaign admits only a request shopping at its site' do
      seller = create(:seller, store: store)
      campaign = create(:site_coupon_campaign, store: store, promotion: promotion)
      campaign.preferred_seller_id = seller.prefixed_id
      customer = create(:customer)

      expect(campaign.eligible_for?(customer)).to be(false)

      Spree::Current.seller = seller
      expect(campaign.eligible_for?(customer)).to be(true)
    end
  end
end
