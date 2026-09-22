require 'spec_helper'

RSpec.describe Spree::Points::Earning do
  let(:store) { @default_store }
  let(:order) { create(:order_with_line_items, store: store, line_items_count: 1) }
  let(:line) { order.line_items.first }
  let(:product) { line.variant.product }

  def earned
    described_class.call(order: order.reload).value
  end

  def set_custom_field(key, value)
    product.set_custom_field(key, value)
    order.line_items.each { |item| item.variant.product.custom_fields.reload }
  end

  before do
    order.update_columns(total: 100)
  end

  it 'earns the paid total over the store’s rate' do
    expect(earned).to eq(100)
  end

  it 'earns on what was paid after every reduction, not on the pre-discount total' do
    order.update_columns(item_total: 150, total: 100)

    expect(earned).to eq(100)
  end

  it 'follows the rate' do
    store.update!(preferred_points_earn_rate: 10)

    expect(earned).to eq(10)
  end

  it 'rounds down, because a point is a whole thing' do
    store.update!(preferred_points_earn_rate: 3)

    expect(earned).to eq(33)
  end

  it 'earns nothing at all below the store’s minimum' do
    store.update!(preferred_points_minimum_order_amount: 200)

    expect(earned).to eq(0)
  end

  it 'earns nothing when the store sets no usable rate' do
    store.update!(preferred_points_earn_rate: 0)

    expect(earned).to eq(0)
  end

  describe '商品积分 — what the goods add on top' do
    it 'adds the good’s own amount for each unit bought' do
      set_custom_field('points.extra_per_unit', 5)
      line.update_columns(quantity: 3)

      expect(earned).to eq(115)
    end

    it 'holds the line to the good’s own cap' do
      set_custom_field('points.extra_per_unit', 5)
      set_custom_field('points.line_cap', 8)
      line.update_columns(quantity: 3)

      expect(earned).to eq(108)
    end

    it 'adds nothing for a good with no setting' do
      expect(earned).to eq(100)
    end

    it 'adds nothing for a setting an operator typed as text' do
      set_custom_field('points.extra_per_unit', 'five')

      expect(earned).to eq(100)
    end
  end

  describe 'the multiplier a day may name' do
    it 'is none until a deployment points the seam at a service' do
      expect(earned).to eq(100)
    end

    it 'multiplies the whole earn' do
      service = instance_double('multiplier', call: 2)
      allow(Spree).to receive(:points_multiplier_service).and_return(service)

      expect(earned).to eq(200)
    end

    it 'ignores a service that answers nothing sensible' do
      service = instance_double('multiplier', call: 0)
      allow(Spree).to receive(:points_multiplier_service).and_return(service)

      expect(earned).to eq(100)
    end
  end
end
