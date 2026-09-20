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

    it 'writes only the lines it is given' do
      touched = cart.line_items.first

      select([touched], false)

      expect(touched.reload.selected).to be(false)
      expect(cart.line_items.last.selected).to be(true)
    end
  end
end
