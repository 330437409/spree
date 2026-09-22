require 'spec_helper'

RSpec.describe Spree::PointAccount, type: :model do
  let(:store) { @default_store }
  let(:customer) { create(:customer) }
  let(:account) { create(:point_account, store: store, customer: customer) }

  describe 'the two balances' do
    it 'refuses a third kind' do
      expect(build(:point_account, store: store, customer: customer, kind: 'wine_value')).not_to be_valid
    end

    it 'is one row per customer per balance' do
      account

      expect(build(:point_account, store: store, customer: customer, kind: 'points')).not_to be_valid
      expect(build(:point_account, store: store, customer: customer, kind: 'growth_value')).to be_valid
    end

    it 'answers the ledger’s two contract methods' do
      expect(account.ledger_unit).to eq('points')
      expect(account.ledger_balance).to eq(0)
      expect(account).to be_points
    end

    it 'answers zero for a balance nobody has written yet' do
      fresh = build(:point_account, store: store, customer: customer, kind: 'growth_value')

      expect(fresh.balance).to eq(0)
      expect(fresh.expiring_total).to eq(0)
      expect(fresh.next_expiry).to be_nil
    end
  end

  describe 'the balance' do
    it 'is the sum of the usable lots, and nothing is stored' do
      create(:point_grant, account: account, amount: 100, remaining: 100)
      create(:point_grant, account: account, amount: 50, remaining: 20)

      expect(account.balance).to eq(120)
    end

    it 'leaves out a lot that already lapsed' do
      lot = create(:point_grant, account: account, amount: 100, remaining: 100)
      lot.grant.update_columns(expires_at: 1.day.ago)

      expect(account.balance).to eq(0)
    end

    it 'leaves out another customer’s lots' do
      other = create(:point_account, store: store, customer: create(:customer))
      create(:point_grant, account: other, amount: 100, remaining: 100)

      expect(account.balance).to eq(0)
    end
  end

  describe 'what is about to lapse' do
    it 'counts only what lapses inside the window, and names the soonest date' do
      soon = create(:point_grant, account: account, amount: 30, remaining: 30)
      soon.grant.update_columns(expires_at: 3.days.from_now)
      later = create(:point_grant, account: account, amount: 70, remaining: 70)
      later.grant.update_columns(expires_at: 90.days.from_now)

      expect(account.expiring_total).to eq(30)
      expect(account.next_expiry).to be_within(1.minute).of(3.days.from_now)
    end

    it 'follows the store’s window' do
      lot = create(:point_grant, account: account, amount: 30, remaining: 30)
      lot.grant.update_columns(expires_at: 10.days.from_now)

      expect(account.expiring_total).to eq(30)
      expect(account.expiring_total(within: 5.days)).to eq(0)
    end

    # 成长值 has no dates at all: the credit service refuses one, so the read
    # never has to ask what "0 points expiring" would mean there.
    it 'reads no window on a balance written without dates' do
      growth = create(:point_account, store: store, customer: customer, kind: 'growth_value')
      create(:point_grant, account: growth, amount: 30, remaining: 30)

      expect(growth.expiring_total).to eq(0)
      expect(growth.next_expiry).to be_nil
      expect(growth.balance).to eq(30)
    end
  end
end
