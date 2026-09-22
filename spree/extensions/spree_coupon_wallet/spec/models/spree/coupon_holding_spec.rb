require 'spec_helper'

RSpec.describe Spree::CouponHolding, type: :model do
  let(:store) { @default_store }
  let(:holding) { create(:coupon_holding, store: store) }

  # The primitive owns the holder, the date and the store; this row owns which
  # code it is.
  it 'reads who holds it, when it lapses and its store off the grant' do
    expect(holding.customer).to eq(holding.grant.customer)
    expect(holding.store).to eq(store)
    expect(holding.expires_at).to eq(holding.grant.expires_at)
  end

  it 'holds one code once, and one grant once' do
    same_code = build(:coupon_holding, store: store, coupon_code: holding.coupon_code)
    same_grant = build(:coupon_holding, store: store, grant: holding.grant)

    expect(same_code).not_to be_valid
    expect(same_grant).not_to be_valid
  end

  # The uniqueness stands where the indexes do, removed rows included: a code
  # somebody gave back is still reserved to the holding it was given under.
  it 'keeps a removed holding’s code reserved to it' do
    removed = create(:coupon_holding, store: store)
    removed.destroy

    expect(build(:coupon_holding, store: store, coupon_code: removed.coupon_code)).not_to be_valid
    expect(build(:coupon_holding, store: store, grant: removed.grant)).not_to be_valid
  end

  it 'refuses a way in that is not one of the wallet’s own' do
    expect(build(:coupon_holding, store: store, source: 'telepathy')).not_to be_valid
  end

  describe 'what the wallet shows' do
    it 'is unused while the code is unapplied and the date has not passed' do
      expect(holding.display_status).to eq('unused')
    end

    it 'is used once the code has been applied to an order' do
      holding.coupon_code.update!(state: 'used')

      expect(holding.display_status).to eq('used')
      expect(holding).to be_used
    end

    it 'is expired once its date has passed, whatever the grant still says' do
      holding.grant.update!(expires_at: 1.day.ago)

      expect(holding.display_status).to eq('expired')
      expect(holding).to be_expired
    end

    it 'is revoked once the store has taken it back' do
      Spree::Grants.revoke!(holding.grant, reason: 'support')

      expect(holding.display_status).to eq('revoked')
    end
  end

  describe 'the wallet’s own tabs' do
    it 'separates what is still usable from what is spent and what has lapsed' do
      spent = create(:coupon_holding, store: store, coupon_code: create(:coupon_code, state: 'used'))
      lapsed = create(:coupon_holding, store: store)
      lapsed.grant.update!(expires_at: 1.day.ago)

      expect(described_class.all).to include(spent, lapsed, holding)
      expect(described_class.unused).to contain_exactly(holding)
      expect(described_class.used).to contain_exactly(spent)
      expect(described_class.expired).to contain_exactly(lapsed)
    end

    it 'scopes the wallet to the customer whose it is' do
      other = create(:coupon_holding, store: store)

      expect(described_class.for_customer(holding.customer)).to contain_exactly(holding)
      expect(described_class.for_customer(holding.customer)).not_to include(other)
    end
  end
end
