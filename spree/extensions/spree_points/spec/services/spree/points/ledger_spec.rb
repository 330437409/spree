require 'spec_helper'

RSpec.describe Spree::Points::Ledger do
  let(:store) { @default_store }
  let(:customer) { create(:customer) }
  let(:account) { create(:point_account, store: store, customer: customer) }
  let(:reason) { create(:point_reason, store: store, key: 'consume', label: '消费获赠') }

  def lot(amount, expires_in:)
    described_class.credit!(account: account, amount: amount, reason: reason,
                            idempotency_key: "lot:#{amount}:#{expires_in}",
                            expires_at: expires_in.from_now).value
  end

  describe '.credit!' do
    def credit!(**options)
      described_class.credit!(account: account, amount: 100, reason: reason, idempotency_key: 'order:1:earn',
                              **options)
    end

    it 'writes the movement, the lot and the account’s total' do
      result = credit!(expires_at: 30.days.from_now)

      expect(result).to be_success
      expect(result.value).to have_attributes(amount: 100, remaining: 100, account: account, reason: reason)

      entry = Spree::LedgerEntry.for_account(account).last
      expect(entry).to have_attributes(kind: 'consume', unit: 'points', amount: 100, balance_after: 100)
      expect(account.reload.lifetime_earned).to eq(100)
      expect(account.balance).to eq(100)
    end

    it 'snapshots the balance the entry leaves behind' do
      credit!
      described_class.credit!(account: account, amount: 50, reason: reason, idempotency_key: 'order:2:earn')

      expect(Spree::LedgerEntry.for_account(account).order(:id).last.balance_after).to eq(150)
      expect(account.balance).to eq(150)
    end

    # What a producer that runs twice is promised.
    it 'answers the lot the first call wrote instead of writing a second one' do
      first = credit!
      second = credit!

      expect(second.value.id).to eq(first.value.id)
      expect(Spree::PointGrant.count).to eq(1)
      expect(account.reload.lifetime_earned).to eq(100)
    end

    it 'takes a reason the operator’s list does not hold yet, and keeps its key' do
      result = described_class.credit!(account: account, amount: 5, reason: 'review_reward',
                                       idempotency_key: 'review:9')

      expect(result).to be_success
      expect(result.value.reason).to be_nil
      expect(Spree::LedgerEntry.for_account(account).last.kind).to eq('review_reward')
    end

    # 成长值 never expires: a date on it is a caller that has confused the two
    # balances rather than a fact to keep.
    it 'refuses an expiry on a balance that never lapses' do
      growth = create(:point_account, store: store, customer: customer, kind: 'growth_value')

      result = described_class.credit!(account: growth, amount: 10, reason: reason,
                                       idempotency_key: 'vip:1', expires_at: 30.days.from_now)

      expect(result).to be_failure
      expect(result.error.value).to eq(:growth_value_does_not_expire)
      expect(growth.reload.balance).to eq(0)
    end

    it 'refuses an amount that is not a credit' do
      expect(credit!(amount: -5).error.value).to eq(:amount_must_be_positive)
      expect(credit!(amount: 0).error.value).to eq(:amount_must_be_positive)
    end

    # Points are an integer count: a fractional one is a producer that has not
    # rounded, not a balance of 1.5 points.
    it 'refuses a fractional amount rather than truncating it' do
      result = credit!(amount: BigDecimal('1.5'))

      expect(result).to be_failure
      expect(result.error.value).to eq(:amount_must_be_whole)
      expect(account.balance).to eq(0)
    end

    # The refusals are real inside a caller's own transaction: without the
    # savepoint the entry written before the refusal would stay behind.
    it 'leaves nothing behind when it refuses inside a caller’s transaction' do
      growth = create(:point_account, store: store, customer: customer, kind: 'growth_value')

      Spree::PointAccount.transaction do
        described_class.credit!(account: growth, amount: 10, reason: reason,
                                idempotency_key: 'vip:inside', expires_at: 1.day.from_now)
      end

      expect(Spree::LedgerEntry.for_account(growth).count).to eq(0)
      expect(Spree::PointGrant.where(account: growth).count).to eq(0)
    end

    it 'refuses a movement with no key' do
      expect(credit!(idempotency_key: nil).error.value).to eq(:key_missing)
    end
  end

  describe '.debit!' do
    let!(:sooner) { lot(60, expires_in: 3.days) }
    let!(:later) { lot(60, expires_in: 90.days) }

    it 'spends what is about to lapse first' do
      entry = described_class.debit!(account: account, amount: 40, reason: reason,
                                     idempotency_key: 'spend:1').value

      expect(sooner.reload.remaining).to eq(20)
      expect(later.reload.remaining).to eq(60)
      expect(entry).to have_attributes(kind: 'consume', amount: -40, unit: 'points')
      expect(Spree::PointAllocation.where(ledger_entry: entry).sum(:amount)).to eq(40)
    end

    it 'walks into the next lot when one is not enough' do
      described_class.debit!(account: account, amount: 80, reason: reason, idempotency_key: 'spend:2')

      expect(sooner.reload.remaining).to eq(0)
      expect(later.reload.remaining).to eq(40)
      expect(account.balance).to eq(40)
    end

    it 'refuses more than the balance holds, and writes nothing' do
      result = described_class.debit!(account: account, amount: 121, reason: reason, idempotency_key: 'spend:3')

      expect(result).to be_failure
      expect(result.error.value).to eq(:insufficient_balance)
      expect(sooner.reload.remaining).to eq(60)
      expect(account.balance).to eq(120)
    end

    it 'spends once when the same key arrives twice' do
      first = described_class.debit!(account: account, amount: 40, reason: reason, idempotency_key: 'spend:4')
      second = described_class.debit!(account: account, amount: 40, reason: reason, idempotency_key: 'spend:4')

      expect(second.value.id).to eq(first.value.id)
      expect(sooner.reload.remaining).to eq(20)
    end

    it 'builds the key from the source when the caller names none' do
      order = create(:order, store: store)
      first = described_class.debit!(account: account, amount: 10, reason: reason, source: order)
      second = described_class.debit!(account: account, amount: 10, reason: reason, source: order)

      expect(first).to be_success
      expect(second.value.id).to eq(first.value.id)
      expect(sooner.reload.remaining).to eq(50)
    end

    # A lot that never expires is spent last: there is no hurry about it. The
    # ordering column exists because MySQL sorts nulls first on ASC, so the
    # obvious `order(:expires_at)` would spend it first and pass on the other
    # two engines.
    it 'spends a lot that never expires after one that does' do
      never = described_class.credit!(account: account, amount: 500, reason: reason,
                                      idempotency_key: 'lot:never').value

      described_class.debit!(account: account, amount: 70, reason: reason, idempotency_key: 'spend:6')

      expect(sooner.reload.remaining).to eq(0)
      expect(later.reload.remaining).to eq(50)
      expect(never.reload.remaining).to eq(500)
    end

    it 'refuses a spend with no source and no key' do
      expect(described_class.debit!(account: account, amount: 10, reason: reason).error.value).to eq(:key_missing)
    end

    it 'refuses a spend with no reason' do
      expect(described_class.debit!(account: account, amount: 10, reason: nil,
                                    idempotency_key: 'spend:5').error.value).to eq(:reason_missing)
    end

    # Growth value is what moves the ladder; it is never spent.
    it 'refuses to spend a balance that is not the spendable one' do
      growth = create(:point_account, store: store, customer: customer, kind: 'growth_value')

      result = described_class.debit!(account: growth, amount: 1, reason: reason, idempotency_key: 'x')

      expect(result).to be_failure
      expect(result.error.value).to eq(:not_a_spendable_balance)
    end
  end

  describe '.balance' do
    it 'is the account’s own derived figure' do
      described_class.credit!(account: account, amount: 70, reason: reason, idempotency_key: 'lot:1')
      described_class.debit!(account: account, amount: 30, reason: reason, idempotency_key: 'spend:9')

      expect(described_class.balance(account)).to eq(40)
    end
  end
end
