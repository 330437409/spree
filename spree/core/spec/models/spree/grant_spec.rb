require 'spec_helper'

RSpec.describe Spree::Grant, type: :model do
  let(:store) { @default_store }
  let(:customer) { create(:customer) }

  # A kind is a class the registry holds; this one is enough to answer the
  # three things the row asks of it.
  def register_kind(api_type, expires: true)
    kind = Class.new do
      define_singleton_method(:api_type) { api_type }
      define_singleton_method(:expires?) { expires }
    end

    Spree.grant_kinds << kind
    kind
  end

  around do |example|
    kept = Spree.grant_kinds.dup
    example.run
  ensure
    Spree.grant_kinds.replace(kept)
  end

  describe 'the idempotency key' do
    it 'refuses a second grant with the same key for the same kind' do
      create(:grant, store: store, customer: customer, kind: 'membership_gift', idempotency_key: 'gift:2026-09')

      duplicate = build(:grant, store: store, customer: customer, kind: 'membership_gift', idempotency_key: 'gift:2026-09')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:idempotency_key]).to be_present
    end

    it 'lets the same key be used by another kind' do
      create(:grant, store: store, customer: customer, kind: 'membership_gift', idempotency_key: 'shared-key')

      expect(build(:grant, store: store, customer: customer, kind: 'points_lot', idempotency_key: 'shared-key')).to be_valid
    end

    it 'lets the same key be used by another store' do
      create(:grant, store: store, customer: customer, idempotency_key: 'shared-key')

      expect(build(:grant, store: create(:store), customer: customer, idempotency_key: 'shared-key')).to be_valid
    end

    # The key says the debt was already recorded. A row someone removed is not
    # a reason to record it again, so the index refuses it just as the
    # validation does.
    it 'stays taken after the row is deleted' do
      grant = create(:grant, store: store, customer: customer, kind: 'membership_gift', idempotency_key: 'gift:2026-09')
      grant.destroy

      expect(build(:grant, store: store, customer: customer, kind: 'membership_gift', idempotency_key: 'gift:2026-09')).not_to be_valid
      expect {
        described_class.new(store: store, customer: customer, kind: 'membership_gift',
                            idempotency_key: 'gift:2026-09', status: 'granted', granted_at: Time.current).save(validate: false)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'expiry' do
    it 'is a date to read, not a status' do
      grant = create(:grant, store: store, customer: customer, expires_at: 1.day.ago)

      expect(grant.status).to eq('granted')
      expect(grant).not_to be_usable
      expect(described_class.expired).to include(grant)
    end

    it 'leaves a grant without one usable' do
      grant = create(:grant, store: store, customer: customer, expires_at: nil)

      expect(described_class.usable).to include(grant)
    end

    it 'drops what has been consumed or revoked, whatever its date' do
      consumed = create(:grant, store: store, customer: customer, status: 'consumed', expires_at: 1.day.from_now)
      revoked = create(:grant, store: store, customer: customer, status: 'revoked')

      expect(consumed).not_to be_usable
      expect(revoked).not_to be_usable
      expect(described_class.usable).not_to include(consumed, revoked)
    end

    it 'answers what a warning banner asks' do
      soon = create(:grant, store: store, customer: customer, expires_at: 3.days.from_now)
      later = create(:grant, store: store, customer: customer, expires_at: 30.days.from_now)

      expect(described_class.expiring_before(7.days.from_now)).to include(soon)
      expect(described_class.expiring_before(7.days.from_now)).not_to include(later)
    end

    it 'refuses a date on a kind that never expires' do
      register_kind('forever_card', expires: false)

      grant = build(:grant, store: store, customer: customer, kind: 'forever_card', expires_at: 1.day.from_now)

      expect(grant).not_to be_valid
      expect(grant.errors[:expires_at]).to be_present
    end

    it 'leaves a kind that never expires without one' do
      register_kind('forever_card', expires: false)

      expect(build(:grant, store: store, customer: customer, kind: 'forever_card')).to be_valid
    end
  end

  describe 'the kind' do
    it 'resolves a registered kind' do
      register_kind('points_lot')

      expect(create(:grant, store: store, customer: customer, kind: 'points_lot').kind_class.api_type).to eq('points_lot')
    end

    # A row outlives the gem that wrote it: an uninstalled extension leaves its
    # grants readable.
    it 'answers nothing for a kind nothing registered' do
      expect(create(:grant, store: store, customer: customer, kind: 'gone_kind').kind_class).to be_nil
    end
  end
end
