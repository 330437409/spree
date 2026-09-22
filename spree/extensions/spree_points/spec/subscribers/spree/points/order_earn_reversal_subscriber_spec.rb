require 'spec_helper'

RSpec.describe Spree::Points::OrderEarnReversalSubscriber do
  let(:store) { @default_store }
  let(:order) { create(:order_with_line_items, store: store, line_items_count: 1) }
  let(:points_account) { Spree::PointAccount.find_by(store: store, customer: order.customer, kind: 'points') }
  let(:growth_account) { Spree::PointAccount.find_by(store: store, customer: order.customer, kind: 'growth_value') }
  let(:subscriber) { described_class.new }

  before do
    order.update_columns(total: 100, payment_status: 'paid')
    allow(Spree).to receive(:points_multiplier_service).and_return(nil)
    Spree::Points::OrderPaidSubscriber.new.handle(double('event', payload: { 'id' => order.prefixed_id }))
  end

  def cancelled
    subscriber.send(:reverse_what_the_order_earned, double('event', payload: { 'id' => order.prefixed_id }))
  end

  def refunded(amount)
    return_record = instance_double(Spree::Return, order: order, refund_total: amount, id: 7)
    allow(Spree::Return).to receive(:find_by_prefix_id).and_return(return_record)
    subscriber.send(:reverse_the_returns_share, double('event', payload: { 'id' => 'ret_whatever' }))
  end

  it 'takes the whole earn back when the order is called off' do
    cancelled

    expect(points_account.reload.balance).to eq(0)
    expect(growth_account.reload.balance).to eq(0)
    expect(points_account.lifetime_earned).to eq(100)
  end

  it 'points the reversal at the earn, with the client’s own reason' do
    cancelled

    earn = Spree::LedgerEntry.for_account(points_account).where(kind: 'consume').first
    reversal = Spree::LedgerEntry.for_account(points_account).where(kind: 'consume_return').first

    expect(reversal).to have_attributes(amount: -100, reverses_entry_id: earn.id, order_id: order.id)
  end

  it 'takes back the return’s share of it when goods come back' do
    refunded(40)

    expect(points_account.reload.balance).to eq(60)
    expect(growth_account.reload.balance).to eq(60)
  end

  it 'reverses once however often the same return is announced' do
    refunded(40)
    refunded(40)

    expect(points_account.reload.balance).to eq(60)
    expect(Spree::LedgerEntry.for_account(points_account).where(kind: 'consume_return').count).to eq(1)
  end

  it 'never takes back more than the earn' do
    refunded(400)

    expect(points_account.reload.balance).to eq(0)
    expect(Spree::LedgerEntry.for_account(points_account).where(kind: 'consume_return').sum(:amount)).to eq(-100)
  end

  # Points a customer has already spent cannot be clawed back: this ledger has
  # no way to write a negative balance.
  it 'never takes back more than the balance holds' do
    Spree::Points::Ledger.debit!(account: points_account, amount: 70, reason: 'consume',
                                 idempotency_key: 'spend:1')

    cancelled

    expect(points_account.reload.balance).to eq(0)
    expect(Spree::LedgerEntry.for_account(points_account).where(kind: 'consume_return').sum(:amount)).to eq(-30)
  end

  it 'does nothing for an order that never earned' do
    quiet = create(:order_with_line_items, store: store, line_items_count: 1)
    quiet.update_columns(total: 100, payment_status: 'paid')

    subscriber.send(:reverse_what_the_order_earned, double('event', payload: { 'id' => quiet.prefixed_id }))

    expect(Spree::PointAccount.where(customer: quiet.customer).count).to eq(0)
    expect(Spree::LedgerEntry.where(order_id: quiet.id).count).to eq(0)
  end
end
