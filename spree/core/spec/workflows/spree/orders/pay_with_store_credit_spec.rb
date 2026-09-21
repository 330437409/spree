require 'spec_helper'

module Spree
  # Events on: the order's own rollup — payment_status and payment_total —
  # is the OrderStatusSubscriber's work, and specs run with the bus off.
  describe Orders::PayWithStoreCredit, events: true do
    subject { described_class }

    let(:store) { @default_store }
    let(:customer) { create(:user) }
    let(:order) { create(:completed_order_with_totals, store: store, customer: customer) }

    let(:result) { subject.call(order: order) }

    before { create(:store_credit_payment_method, store: store) }

    context 'with a balance that covers the order' do
      let!(:credit) { create(:store_credit, customer: customer, store: store, amount: order.total) }

      it 'pays the order' do
        expect(result.success?).to be(true)
        expect(order.reload.payment_state).to eq('paid')
        expect(order.outstanding_balance).to eq(0)
      end

      # Applying is not paying: a credit left in checkout on a completed order
      # holds money the customer cannot spend anywhere else.
      it 'spends the balance rather than reserving it' do
        result

        expect(credit.reload.amount_remaining).to eq(0)
        expect(order.payments.store_credits.map(&:status)).to eq(['completed'])
      end
    end

    context 'with a balance that does not cover the order' do
      let!(:credit) do
        create(:store_credit, customer: customer, store: store, amount: order.total - 1)
      end

      it 'refuses, naming what is missing, and leaves the balance alone' do
        expect(result.success?).to be(false)
        expect(result.error.to_s).to include('does not cover')
        expect(credit.reload.amount_remaining).to eq(order.total - 1)
        expect(order.reload.payments).to be_empty
      end
    end

    context 'when the customer holds no balance at all' do
      it 'refuses' do
        expect(result.success?).to be(false)
        expect(order.reload.payments).to be_empty
      end
    end

    context 'when the order owes nothing' do
      let!(:credit) { create(:store_credit, customer: customer, store: store, amount: order.total) }

      before { order.update_columns(payment_total: order.total, payment_state: 'paid') }

      it 'refuses and spends nothing' do
        expect(result.success?).to be(false)
        expect(result.error.to_s).to eq('nothing is owed on this order')
        expect(credit.reload.amount_remaining).to eq(order.total)
      end
    end

    context 'when the order carries another tender that has not been processed' do
      let!(:credit) { create(:store_credit, customer: customer, store: store, amount: order.total) }
      let!(:card_payment) { create(:payment, order: order, amount: order.total) }

      it 'settles only what this balance paid' do
        result

        expect(card_payment.reload.status).to eq('checkout')
      end
    end
  end
end
