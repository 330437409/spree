require 'spec_helper'

RSpec.describe Spree::Grants do
  let(:store) { create(:store) }
  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }

  describe '.grant!' do
    it 'records the debt under the kind’s own key' do
      result = described_class.grant!(store: store, customer: customer, kind: 'spec_gift', source: nil, context: '2026-09')

      expect(result).to be_success
      expect(result.value).to have_attributes(
        store_id: store.id, customer_id: customer.id, kind: 'spec_gift',
        idempotency_key: 'gift:2026-09', status: 'granted'
      )
      expect(result.value.granted_at).to be_present
    end

    it 'takes the kind as a class or as its name' do
      result = described_class.grant!(store: store, customer: customer, kind: SpecGrantKinds::Gift, context: '2026-09')

      expect(result.value.kind).to eq('spec_gift')
    end

    # What a job that runs twice is promised: nothing new is written, and the
    # caller still gets the grant the first run recorded.
    it 'answers the existing grant instead of recording a second one' do
      first = described_class.grant!(store: store, customer: customer, kind: 'spec_gift', context: '2026-09')
      second = described_class.grant!(store: store, customer: customer, kind: 'spec_gift', context: '2026-09')

      expect(second).to be_success
      expect(second.value.id).to eq(first.value.id)
      expect(Spree::Grant.count).to eq(1)
    end

    it 'lets a caller that built the key itself pass it in' do
      result = described_class.grant!(store: store, customer: customer, kind: 'spec_gift', idempotency_key: 'built:by:caller')

      expect(result.value.idempotency_key).to eq('built:by:caller')
    end

    it 'records when the debt stops being owed, and what it released' do
      issued = create(:store_credit, store: store, customer: customer)
      result = described_class.grant!(store: store, customer: customer, kind: 'spec_gift', context: '2026-09',
                                      issued: issued, expires_at: 30.days.from_now)

      expect(result.value.issued).to eq(issued)
      expect(result.value).to be_usable
    end

    it 'takes the store from the request when the caller names none' do
      Spree::Current.store = store

      expect(described_class.grant!(customer: customer, kind: 'spec_gift', context: '2026-09').value.store).to eq(store)
    end

    it 'falls back to the default store when neither the caller nor the request names one' do
      store

      expect(described_class.grant!(customer: customer, kind: 'spec_gift', context: '2026-09').value.store).to eq(Spree::Store.default)
    end

    it 'refuses a shorthand no gem registered' do
      expect {
        described_class.grant!(store: store, customer: customer, kind: 'nothing_claims_this', idempotency_key: 'k')
      }.to raise_error(Spree::Grants::UnknownKind, /nothing_claims_this/)
    end

    it 'answers a store nothing can supply rather than raising' do
      allow(Spree::Current).to receive(:store).and_return(nil)

      result = described_class.grant!(customer: customer, kind: 'spec_gift', context: '2026-09')

      expect(result).to be_failure
      expect(result.error.to_s).to match(/Store/)
    end

    it 'refuses a debt with no key at all' do
      keyless = Class.new(Spree::Grants::Kind) do
        def self.api_type
          'spec_keyless'
        end

        def self.idempotency_key_for(_context)
          nil
        end
      end
      Spree.grant_kinds << keyless

      result = described_class.grant!(store: store, customer: customer, kind: 'spec_keyless')

      expect(result).to be_failure
      expect(result.error.value).to eq(:key_missing)
    end

    it 'refuses an expiry on a kind that never expires' do
      result = described_class.grant!(store: store, customer: customer, kind: 'spec_card',
                                      context: 'card-1', expires_at: 1.day.from_now)

      expect(result).to be_failure
      expect(result.error.to_s).to match(/never expires/)
    end
  end

  describe '.claim!' do
    it 'gives an unclaimed grant its holder' do
      grant = create(:grant, store: store, customer: nil, kind: 'spec_gift')

      result = described_class.claim!(grant, customer: customer)

      expect(result).to be_success
      expect(grant.reload.customer_id).to eq(customer.id)
      expect(grant.status).to eq('claimed')
    end

    it 'answers the same holder with the same grant rather than claiming twice' do
      grant = create(:grant, store: store, customer: customer, status: 'claimed')

      expect(described_class.claim!(grant, customer: customer)).to be_success
      expect(grant.reload.status).to eq('claimed')
    end

    it 'refuses a grant that already belongs to somebody else' do
      grant = create(:grant, store: store, customer: other_customer, status: 'claimed')

      result = described_class.claim!(grant, customer: customer)

      expect(result).to be_failure
      expect(result.error.value).to eq(:already_claimed)
      expect(grant.reload.customer_id).to eq(other_customer.id)
    end

    it 'refuses what is no longer owed' do
      grant = create(:grant, store: store, customer: nil, status: 'revoked')

      expect(described_class.claim!(grant, customer: customer)).to be_failure
    end
  end

  describe '.consume!' do
    it 'stamps a one-shot grant through its kind' do
      grant = create(:grant, store: store, customer: customer, kind: 'spec_gift')

      result = described_class.consume!(grant)

      expect(result).to be_success
      expect(grant.reload.status).to eq('consumed')
      expect(grant).not_to be_usable
    end

    it 'lets a partial kind consume through the plan that owns the thing' do
      grant = create(:grant, store: store, customer: customer, kind: 'spec_lot')

      described_class.consume!(grant)

      expect(grant.reload.metadata['through']).to eq('the owner')
    end

    it 'refuses what is expired or already spent' do
      expired = create(:grant, store: store, customer: customer, expires_at: 1.minute.ago)
      spent = create(:grant, store: store, customer: customer, status: 'consumed')

      expect(described_class.consume!(expired).error.value).to eq(:not_usable)
      expect(described_class.consume!(spent).error.value).to eq(:not_usable)
    end

    it 'refuses a kind that is not consumable at all' do
      grant = create(:grant, store: store, customer: customer, kind: 'spec_card')

      result = described_class.consume!(grant)

      expect(result).to be_failure
      expect(result.error.value).to eq(:not_consumable)
      expect(grant.reload.status).to eq('granted')
    end

    it 'refuses a row whose kind is no longer registered' do
      grant = create(:grant, store: store, customer: customer, kind: 'gone_kind')

      expect(described_class.consume!(grant).error.value).to eq(:unknown_kind)
    end
  end

  describe '.revoke!' do
    it 'takes the debt back and keeps the row' do
      grant = create(:grant, store: store, customer: customer, kind: 'spec_gift')

      result = described_class.revoke!(grant, reason: 'issued in error')

      expect(result).to be_success
      expect(grant.reload.status).to eq('revoked')
      expect(grant.metadata['revocation_reason']).to eq('issued in error')
      expect(grant).not_to be_usable
    end

    it 'revoking twice is not an error' do
      grant = create(:grant, store: store, customer: customer, status: 'revoked')

      expect(described_class.revoke!(grant)).to be_success
    end

    it 'refuses to take back what was consumed' do
      grant = create(:grant, store: store, customer: customer, status: 'consumed')

      result = described_class.revoke!(grant)

      expect(result).to be_failure
      expect(result.error.value).to eq(:already_consumed)
    end
  end
end
