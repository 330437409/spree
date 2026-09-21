require 'spec_helper'

module Spree
  RSpec.describe Carts::SelectLines do
    let(:store) { @default_store }
    let(:cart) { create(:cart_with_line_items, store: store, line_items_count: 2, line_items_price: 15) }

    def select(lines, selected)
      described_class.call(
        cart: cart,
        line_items: cart.line_items.where(id: Array(lines).map(&:id)),
        selected: selected
      )
    end

    it 'writes the ticks and re-prices the cart for the new selection' do
      result = select([cart.line_items.last], false)

      expect(result).to be_success
      expect(cart.reload.line_items.selected.count).to eq(1)
      expect(cart.item_total).to eq(15)
      expect(cart.selected_quantity).to eq(1)
    end

    it 'ticks them back on' do
      cart.line_items.each { |line_item| line_item.update_column(:selected, false) }
      cart.recalculate_totals!

      select(cart.line_items, true)

      expect(cart.reload.item_total).to eq(30)
    end

    # A client re-sending the set it already has — select-all over an
    # already-ticked cart — must not pay for the money math.
    it 'leaves the cart alone when every line already says what the write would' do
      cart.recalculate_totals!
      expect(Spree).not_to receive(:cart_recalculate_workflow)

      expect(select(cart.line_items, true)).to be_success
    end

    describe 'the stock a line holds' do
      let(:unticked) { cart.line_items.last }

      before do
        stub_store_preferences(store, stock_reservations_enabled: true)
        cart.line_items.each do |line_item|
          variant = line_item.variant
          variant.update!(track_inventory: true)
          variant.stock_levels.first.tap do |level|
            level.stock_location.update!(active: true)
            level.update!(backorderable: false)
            level.set_count_on_hand(5)
          end
        end
      end

      # A line nobody is buying must not keep its stock out of the shop until
      # the reservation expires.
      it 'gives the stock back when a tick comes off' do
        Spree::StockReservations::Reserve.call(cart: cart)
        expect(cart.stock_reservations.count).to eq(2)

        select(unticked, false)

        expect(cart.stock_reservations.reload.pluck(:line_item_id)).to eq([cart.line_items.first.id])
        expect(unticked.variant.stock_levels.first.reload.reserved_count).to eq(0)
      end

      # Ticking a line back is a shopper taking a place in the queue again.
      it 'takes the hold back when the line is ticked again' do
        select(unticked, false)
        select(unticked, true)

        expect(cart.stock_reservations.reload.pluck(:line_item_id)).to include(unticked.id)
      end

      # A tick moved nothing, so nothing about the hold moved either — not even
      # its clock.
      it 'leaves the holds alone when the write changes nothing' do
        Spree::StockReservations::Reserve.call(cart: cart)
        held = cart.stock_reservations.reload.pluck(:line_item_id, :quantity, :expires_at)

        select(cart.line_items, true)

        expect(cart.stock_reservations.reload.pluck(:line_item_id, :quantity, :expires_at)).to eq(held)
      end
    end

    it 'writes only the lines it is given' do
      touched = cart.line_items.first

      select([touched], false)

      expect(touched.reload.selected).to be(false)
      expect(cart.line_items.last.selected).to be(true)
    end
  end
end
