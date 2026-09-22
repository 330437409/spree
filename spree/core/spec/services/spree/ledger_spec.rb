require 'spec_helper'

RSpec.describe Spree::Ledger do
  let(:store) { @default_store }
  let(:account) { create(:customer) }
  let(:source) { create(:order, store: store) }

  # The contract is two methods, so a spec gives the account both and asks
  # what the service does with the answers.
  before do
    allow(account).to receive(:ledger_unit).and_return('points')
    allow(account).to receive(:ledger_balance).and_return(120)
  end

  describe '.record!' do
    def record!(**options)
      described_class.record!(account: account, kind: 'earn', amount: 50, idempotency_key: 'order:1:earn', **options)
    end

    it 'writes what the account says its unit is, and where it says the balance stands' do
      result = record!(source: source)

      expect(result).to be_success
      expect(result.value).to have_attributes(
        store_id: store.id, account: account, kind: 'earn', unit: 'points',
        amount: 50, balance_after: 170, source: source
      )
      expect(result.value.occurred_at).to be_present
    end

    # The account answers where its balance stands now, and the column
    # promises where it stood after: for an account whose balance is its
    # history, that addition is the only way the snapshot can be true.
    it 'snapshots where the balance stands once the movement is written' do
      allow(account).to receive(:ledger_balance) { Spree::LedgerEntry.balance_for(account, unit: 'points') }

      described_class.record!(account: account, kind: 'earn', amount: 50, idempotency_key: 'order:1:earn')
      second = described_class.record!(account: account, kind: 'spend', amount: -20, idempotency_key: 'order:2:spend')

      expect(second.value.balance_after).to eq(30)
    end

    it 'leaves the snapshot null where the instrument is authoritative' do
      allow(account).to receive(:ledger_balance).and_return(nil)

      expect(record!.value.balance_after).to be_nil
    end

    it 'writes a spend as a negative amount' do
      expect(record!(kind: 'spend', amount: -30).value.amount).to eq(-30)
    end

    # What a retried webhook is promised.
    it 'answers the entry the first call wrote instead of writing a second one' do
      first = record!
      second = record!

      expect(second.value.id).to eq(first.value.id)
      expect(Spree::LedgerEntry.count).to eq(1)
    end

    it 'takes the account’s own store over the request’s' do
      other_store = create(:store)
      allow(account).to receive(:store).and_return(other_store)

      expect(record!.value.store).to eq(other_store)
    end

    it 'refuses an account that answers neither contract method, and names what is missing' do
      product = create(:product, store: store)

      expect {
        described_class.record!(account: product, kind: 'earn', amount: 1, idempotency_key: 'k')
      }.to raise_error(Spree::Ledger::NotAnAccount, /ledger_unit or ledger_balance/)
    end

    it 'refuses an account that answers only one of them' do
      half = double('half an account', ledger_unit: 'points')

      expect {
        described_class.record!(account: half, kind: 'earn', amount: 1, idempotency_key: 'k')
      }.to raise_error(Spree::Ledger::NotAnAccount, /ledger_balance/)
    end

    it 'refuses a movement with no key' do
      expect(record!(idempotency_key: nil)).to be_failure
    end

    it 'refuses a movement with no amount rather than raising' do
      result = record!(amount: nil)

      expect(result).to be_failure
      expect(result.error.to_s).to match(/Amount/)
    end

    # A key too coarse to tell two movements apart would otherwise drop the
    # second one with no row and no error.
    it 'refuses a key already used for another movement' do
      record!

      result = described_class.record!(account: account, kind: 'expire', amount: -10,
                                       idempotency_key: 'order:1:earn')

      expect(result).to be_failure
      expect(result.error.value).to eq(:key_reused)
      expect(Spree::LedgerEntry.count).to eq(1)
    end

    it 'names a movement’s unit when it is not the account’s own' do
      result = described_class.record!(account: account, kind: 'earn', amount: 5, unit: 'USD',
                                       idempotency_key: 'order:9:earn')

      expect(result.value.unit).to eq('USD')
      expect(Spree::LedgerEntry.balance_for(account, unit: 'USD')).to eq(5)
      expect(Spree::LedgerEntry.balance_for(account, unit: 'points')).to eq(0)
    end

    it 'falls back to the request’s store when the account carries none' do
      result = record!

      expect(result.value.store).to eq(store)
    end
  end

  describe '.reverse!' do
    let!(:earned) { described_class.record!(account: account, kind: 'earn', amount: 50, idempotency_key: 'order:1:earn').value }

    it 'writes the negative counterpart, pointing at what it undoes' do
      result = described_class.reverse!(earned, idempotency_key: 'refund:1:earn')

      expect(result).to be_success
      expect(result.value).to have_attributes(
        account: account, kind: 'reversal', unit: 'points', amount: -50, reverses_entry: earned
      )
    end

    it 'leaves the account back where it started' do
      described_class.reverse!(earned, idempotency_key: 'refund:1:earn')

      expect(Spree::LedgerEntry.balance_for(account, unit: 'points')).to eq(0)
    end

    # The sharper half of the key rule: a caller reusing the original entry's
    # key must not be told the reversal happened.
    it 'refuses to reverse under a key the original already holds' do
      result = described_class.reverse!(earned, idempotency_key: 'order:1:earn')

      expect(result).to be_failure
      expect(result.error.value).to eq(:key_reused)
      expect(result.value).to eq(earned)
      expect(Spree::LedgerEntry.reversals.count).to eq(0)
    end

    it 'carries the entry’s metadata, and a source the caller names' do
      refund = create(:order, store: store)
      entry = described_class.record!(account: account, kind: 'earn', amount: 50,
                                      idempotency_key: 'order:3:earn',
                                      metadata: { 'reason' => 'signup bonus' }).value

      result = described_class.reverse!(entry, idempotency_key: 'refund:3:earn', source: refund)

      expect(result.value.metadata['reason']).to eq('signup bonus')
      expect(result.value.source).to eq(refund)
    end

    it 'reversing twice with one key writes one row' do
      first = described_class.reverse!(earned, idempotency_key: 'refund:1:earn')
      second = described_class.reverse!(earned, idempotency_key: 'refund:1:earn')

      expect(second.value.id).to eq(first.value.id)
      expect(Spree::LedgerEntry.reversals.count).to eq(1)
    end

    # A producer that has a source of its own — the refund rather than the
    # order it refunds — writes the row itself, and the sign is still not its
    # decision.
    it 'forces the opposite sign on a reversal a producer writes itself' do
      result = described_class.record!(account: account, kind: 'consume_return', amount: 50,
                                       idempotency_key: 'refund:1:return', reverses: earned)

      expect(result.value.amount).to eq(-50)
      expect(result.value.unit).to eq('points')
    end

    it 'credits back what a spend took' do
      spent = described_class.record!(account: account, kind: 'spend', amount: -30, idempotency_key: 'order:2:spend').value

      result = described_class.record!(account: account, kind: 'consume_return', amount: 30,
                                       idempotency_key: 'refund:2:return', reverses: spent)

      expect(result.value.amount).to eq(30)
      expect(Spree::LedgerEntry.balance_for(account, unit: 'points')).to eq(50)
    end
  end
end
