require 'spec_helper'

module Spree
  RSpec.describe Carts::RecalculateTotals do
    let(:store) { @default_store }

    describe 'live records' do
      let(:order) { create(:order_with_line_items, store: store, line_items_count: 2, line_items_price: 10) }

      it 'recomputes item count and money totals from the rows and persists them' do
        order.update_columns(item_total: 0, total_quantity: 0, total: 0)

        result = described_class.call(cart: order)

        expect(result).to be_success
        order.reload
        expect(order.total_quantity).to eq(2)
        expect(order.item_total).to eq(20)
        expect(order.total).to eq(order.item_total + order.delivery_total + order.adjustment_total)
      end

      it 'nets refunds out of the payment total' do
        order = create(:completed_order_with_totals, store: store)
        payment = create(:payment, order: order, amount: order.total, status: 'completed')
        create(:refund, payment: payment, amount: 5)

        described_class.call(cart: order)

        expect(order.reload.payment_total).to eq(payment.amount - 5)
      end

      # The cart's scoping is the cart's: an order was completed from ticked
      # lines, so every line it holds is priced even if the column is flipped
      # on it afterwards. This is the guard on the seam the cart overrides.
      it 'prices every line of an order' do
        order.line_items.last.update_column(:selected, false)

        described_class.call(cart: order)

        expect(order.reload.item_total).to eq(20)
      end

      it 'leaves the derived statuses alone, so a stale instance cannot undo them' do
        order = create(:completed_order_with_totals, store: store)
        Spree::Order.where(id: order.id).update_all(payment_status: 'refunded', fulfillment_status: 'fulfilled')
        order.send(:write_attribute, :payment_status, 'paid')
        order.send(:write_attribute, :fulfillment_status, 'pending')

        described_class.call(cart: order)

        order.reload
        expect(order.payment_status).to eq('refunded')
        expect(order.fulfillment_status).to eq('fulfilled')
      end
    end

    describe 'the completed-order money freeze' do
      let(:order) { create(:completed_order_with_totals, store: store) }

      it 'never regenerates typed rows but re-sums them (the post-placement resum path)' do
        # The order's own provider, not the global default — selection is
        # per-market since 6.0, so stubbing the global would assert nothing.
        provider = instance_double(Spree::TaxProvider::Internal)
        allow(order).to receive(:tax_provider).and_return(provider)
        expect(provider).not_to receive(:estimate)

        line_item = order.line_items.first
        order.discounts.create!(line_item: line_item, label: 'Manual', amount: -3,
                                kind: 'manual', value: 3, value_type: 'flat')

        expect { described_class.call(cart: order) }
          .to change { order.reload.discount_total }.by(0).and change { order.reload.adjustment_total }.by(-3)
      end

      # A commission settles between the platform and the seller, so the
      # columns report it beside what the shopper owes and never inside it.
      # The fee and its tax stay apart because the tax is separately
      # reportable on both sides of that supply.
      it 're-sums the commission lines without charging them to the customer' do
        seller = create(:seller, :approved, store: store)
        create(:commission_line, order: order, seller: seller,
                                 line_item: order.line_items.first,
                                 amount: 8, tax_amount: 2, total: 10)
        order.update_columns(commission_amount_total: 0, commission_tax_total: 0,
                             commission_total: 0)

        total_before = order.total
        adjustment_before = order.adjustment_total

        described_class.call(cart: order)

        order.reload
        expect(order).to have_attributes(commission_amount_total: 8,
                                         commission_tax_total: 2,
                                         commission_total: 10)
        expect(order.total).to eq(total_before)
        expect(order.adjustment_total).to eq(adjustment_before)
      end

      it 'reports no commission on an order nobody was charged for' do
        order.update_columns(commission_amount_total: 9, commission_tax_total: 90,
                             commission_total: 99)

        described_class.call(cart: order)

        expect(order.reload).to have_attributes(commission_amount_total: 0,
                                                commission_tax_total: 0,
                                                commission_total: 0)
      end
    end

    describe 'carts' do
      let(:cart) { create(:cart_with_line_items, store: store, line_items_count: 1, line_items_price: 15) }

      it 'recomputes cart totals through the same flow' do
        cart.update_columns(item_total: 0, total: 0, total_quantity: 0)

        described_class.call(cart: cart)

        cart.reload
        expect(cart.item_total).to eq(15)
        expect(cart.total_quantity).to eq(1)
        expect(cart.total).to eq(cart.item_total + cart.delivery_total + cart.adjustment_total)
      end

      # A cart has no commission_lines association at all, so the guard in
      # refresh_commission_totals is what stops the re-sum raising here.
      it 'recalculates without reaching for commission a cart cannot have' do
        expect(cart).not_to respond_to(:commission_lines)

        expect { described_class.call(cart: cart) }.not_to raise_error
        expect(described_class.call(cart: cart)).to be_success
      end
    end

    # The selection is an input to the cart's money, not a filter over it: an
    # unticked line is still in the cart, and still counted by the counts, but
    # nothing it carries reaches the money the shopper is shown.
    describe 'a cart with an unticked line' do
      let(:cart) { create(:cart_with_line_items, store: store, line_items_count: 2, line_items_price: 15) }
      let(:unticked) { cart.line_items.last }

      before { unticked.update_column(:selected, false) }

      it 'prices the ticked lines, while the counts stay the whole cart' do
        described_class.call(cart: cart)

        cart.reload
        expect(cart.item_total).to eq(15)
        expect(cart.total).to eq(cart.item_total + cart.delivery_total + cart.adjustment_total)
        expect(cart.total_quantity).to eq(2)
        expect(cart.selected_quantity).to eq(1)
      end

      # Excluded rather than deleted: the shopper can tick the line again, and
      # nothing would write a merchant's manual discount back if it were gone.
      it 'keeps a discount on an unticked line on the line and out of the money' do
        discount = cart.discounts.create!(line_item: unticked, label: 'Manual', amount: -5,
                                          kind: 'manual', value: 5, value_type: 'flat')

        described_class.call(cart: cart)
        expect(cart.reload.adjustment_total).to eq(0)

        unticked.update_column(:selected, true)
        described_class.call(cart: cart)

        expect(cart.reload.adjustment_total).to eq(-5)
        expect(discount.reload).to be_present
      end

      # A fee is a charge and a discount is a concession, so the rule has to
      # hold for both: a fee standing on a line the shopper is not buying is
      # as out of place in the cart's money as a discount on it.
      it 'keeps a fee charged to an unticked line out of the cart' do
        create(:fee, cart: cart, order: nil, line_item: unticked, amount: 7,
                     kind: 'surcharge', label: 'Handling')

        described_class.call(cart: cart)

        expect(cart.reload.fee_total).to eq(0)
        expect(cart.adjustment_total).to eq(0)
      end

      it 'keeps a tax row on an unticked line on the line and out of the cart' do
        tax_line = create(:tax_line, :on_cart, line_item: unticked, cart: cart, amount: 3)

        described_class.call(cart: cart)

        expect(cart.reload.additional_tax_total).to eq(0)
        expect(tax_line.reload).to be_present
      end
    end
  end
end
