require 'spec_helper'

RSpec.describe Spree::LedgerEntry, type: :model do
  let(:store) { @default_store }
  let(:account) { create(:customer) }

  describe 'append-only' do
    it 'refuses to change a persisted entry' do
      entry = create(:ledger_entry, store: store, account: account)

      expect(entry).to be_readonly
      expect { entry.update(amount: 5) }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect(entry.reload.amount).to eq(10)
    end

    it 'writes a new one' do
      expect(create(:ledger_entry, store: store, account: account)).to be_persisted
    end
  end

  describe 'the producer’s key' do
    it 'is unique per account' do
      create(:ledger_entry, store: store, account: account, idempotency_key: 'order:1:earn')

      duplicate = build(:ledger_entry, store: store, account: account, idempotency_key: 'order:1:earn')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:idempotency_key]).to be_present
    end

    it 'may be the same word for another account' do
      create(:ledger_entry, store: store, account: account, idempotency_key: 'order:1:earn')

      expect(build(:ledger_entry, store: store, account: create(:customer), idempotency_key: 'order:1:earn')).to be_valid
    end
  end

  describe 'a reversal' do
    let(:earned) { create(:ledger_entry, store: store, account: account, unit: 'points', amount: 50) }

    it 'carries the opposite sign in the same unit' do
      reversal = build(:ledger_entry, store: store, account: account, unit: 'points', amount: -50,
                                      reverses_entry: earned)

      expect(reversal).to be_valid
    end

    it 'refuses to move the same way as what it undoes' do
      reversal = build(:ledger_entry, store: store, account: account, unit: 'points', amount: 50,
                                      reverses_entry: earned)

      expect(reversal).not_to be_valid
      expect(reversal.errors[:amount]).to be_present
    end

    it 'refuses to undo an entry of another account' do
      reversal = build(:ledger_entry, store: store, account: create(:customer), unit: 'points', amount: -50,
                                      reverses_entry: earned)

      expect(reversal).not_to be_valid
      expect(reversal.errors[:account]).to be_present
    end

    it 'refuses a unit of its own' do
      reversal = build(:ledger_entry, store: store, account: account, unit: 'USD', amount: -50,
                                      reverses_entry: earned)

      expect(reversal).not_to be_valid
      expect(reversal.errors[:unit]).to be_present
    end
  end

  describe 'reading a balance' do
    it 'sums one unit and leaves the others alone' do
      create(:ledger_entry, store: store, account: account, unit: 'points', amount: 50)
      create(:ledger_entry, store: store, account: account, unit: 'points', amount: -20)
      create(:ledger_entry, store: store, account: account, unit: 'USD', amount: 5)
      create(:ledger_entry, store: store, account: create(:customer), unit: 'points', amount: 100)

      expect(described_class.balance_for(account, unit: 'points')).to eq(30)
      expect(described_class.balance_for(account, unit: 'USD')).to eq(5)
    end

    it 'reads one account’s history in time order' do
      later = create(:ledger_entry, store: store, account: account, occurred_at: 2.days.ago)
      sooner = create(:ledger_entry, store: store, account: account, occurred_at: 1.day.ago)

      expect(described_class.for_account(account).chronological).to eq([later, sooner])
    end
  end
end
