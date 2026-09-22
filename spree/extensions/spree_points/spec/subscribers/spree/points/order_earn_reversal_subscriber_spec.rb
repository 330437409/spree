require 'spec_helper'

RSpec.describe Spree::Points::OrderEarnReversalSubscriber do
  let(:store) { @default_store }
  let(:order) { create(:order_with_line_items, store: store, line_items_count: 1) }
  let(:points_account) { Spree::PointAccount.find_by(store: store, customer: order.customer, kind: 'points') }
  let(:growth_account) { Spree::PointAccount.find_by(store: store, customer: order.customer, kind: 'growth_value') }
  let(:subscriber) { described_class.new }

  before do
    # The goods are worth what the order totals here, so a return's share is
    # read against the same figure the earn was computed on.
    order.update_columns(item_total: 100, total: 100, payment_status: 'paid')
    allow(Spree).to receive(:points_multiplier_service).and_return(nil)
    Spree::Points::OrderPaidSubscriber.new.handle(double('event', payload: { 'id' => order.prefixed_id }))
  end

  def cancelled
    subscriber.send(:reverse_what_the_order_earned, double('event', payload: { 'id' => order.prefixed_id }))
  end

  def refunded(amount, id: 7)
    return_record = instance_double(Spree::Return, order: order, refund_total: amount, id: id)
    allow(Spree::Return).to receive(:find_by_prefix_id).and_return(return_record)
    subscriber.send(:reverse_the_returns_share, double('event', payload: { 'id' => "ret_#{id}" }))
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

  # A return that was refunded and then a cancellation: the two events share
  # one earn, and together they take back exactly what was earned.
  it 'takes back only the rest when the order is called off after a refund' do
    refunded(40)
    cancelled

    expect(points_account.reload.balance).to eq(0)
    expect(Spree::LedgerEntry.for_account(points_account).where(kind: 'consume_return').sum(:amount)).to eq(-100)
  end

  # Two separate returns, not one announced twice: each asks for its own share,
  # and the pair together must not exceed the earn.
  it 'takes each of two returns’ shares back' do
    refunded(40, id: 1)
    refunded(30, id: 2)

    expect(points_account.reload.balance).to eq(30)
    expect(Spree::LedgerEntry.for_account(points_account).where(kind: 'consume_return').sum(:amount)).to eq(-70)
  end

  # The allocation trail is what explains the customer's history, so a clawback
  # gives back the earn's own lot before it touches the rest of the balance.
  it 'gives back the earn’s own lot before another one' do
    own = Spree::PointGrant.where(account: points_account).first
    # A lot that lapses sooner than the earn's own: soonest-expiry-first would
    # drain this one first, which would misattribute the clawback.
    Spree::Points::Ledger.credit!(account: points_account, amount: 50, reason: 'manual',
                                  idempotency_key: 'later:lot', expires_at: 1.day.from_now)
    later = Spree::PointGrant.where(account: points_account).order(:id).last

    cancelled

    expect(own.reload.remaining).to eq(0)
    expect(later.reload.remaining).to eq(50)
    expect(points_account.reload.balance).to eq(50)
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
