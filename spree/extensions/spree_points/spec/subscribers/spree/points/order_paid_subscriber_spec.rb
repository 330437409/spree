require 'spec_helper'

RSpec.describe Spree::Points::OrderPaidSubscriber do
  let(:store) { @default_store }
  let(:order) { create(:order_with_line_items, store: store, line_items_count: 1) }
  let(:event) { double('event', payload: { 'id' => order.prefixed_id }) }
  let(:points_account) { Spree::PointAccount.find_by(store: store, customer: order.customer, kind: 'points') }
  let(:growth_account) { Spree::PointAccount.find_by(store: store, customer: order.customer, kind: 'growth_value') }

  before do
    order.update_columns(total: 100, payment_status: 'paid')
    allow(Spree).to receive(:points_multiplier_service).and_return(nil)
  end

  def handle
    described_class.new.handle(event)
  end

  it 'credits both balances' do
    handle

    expect(points_account.balance).to eq(100)
    expect(growth_account.balance).to eq(100)
  end

  it 'records why, and the order it came from' do
    handle

    entry = Spree::LedgerEntry.for_account(points_account).first
    expect(entry).to have_attributes(kind: 'consume', unit: 'points', amount: 100,
                                     order_id: order.id, source: order)
  end

  # Points lapse, 成长值 never does: the expiry is the store's window on one
  # balance and absent on the other.
  it 'gives the points an expiry and the growth value none' do
    handle

    expect(Spree::PointGrant.find_by(account: points_account).grant.expires_at).to be_present
    expect(Spree::PointGrant.find_by(account: growth_account).grant.expires_at).to be_nil
  end

  it 'earns once however often the event arrives' do
    handle
    handle

    expect(Spree::PointGrant.where(account: points_account).count).to eq(1)
    expect(points_account.reload.balance).to eq(100)
  end

  it 'earns nothing, and writes nothing, below the store’s minimum' do
    store.update!(preferred_points_minimum_order_amount: 1_000)

    handle

    expect(Spree::PointAccount.count).to eq(0)
  end

  it 'credits a customer who has never earned before' do
    expect(Spree::PointAccount.where(customer: order.customer)).to be_empty

    handle

    expect(Spree::PointAccount.where(store: store, customer: order.customer).count).to eq(2)
  end

  it 'attributes the movement to the shop when the order has one seller' do
    seller = create(:seller, store: store)
    order.line_items.first.variant.update_columns(seller_id: seller.id)

    handle

    expect(Spree::LedgerEntry.for_account(points_account).first.seller_id).to eq(seller.id)
  end

  it 'leaves the seller empty when the order’s goods come from several' do
    order.line_items.first.variant.update_columns(seller_id: create(:seller, store: store).id)
    other_line = create(:line_item, order: order, variant: create(:variant, product: create(:product, store: store)))
    other_line.variant.update_columns(seller_id: create(:seller, store: store).id)

    handle

    expect(Spree::LedgerEntry.for_account(points_account).first.seller_id).to be_nil
  end
end
