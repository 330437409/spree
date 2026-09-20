require 'spec_helper'

RSpec.describe Spree::ProductBundle, type: :model do
  let(:store) { Spree::Store.default || create(:store, default: true) }
  # The operator's own catalogue: a bundle of components that all belong to one
  # seller, which the cross-seller validation reads.
  let(:tea) { create(:product, store: store, seller: nil, price: 60).default_variant }
  let(:cup) { create(:product, store: store, seller: nil, price: 40).default_variant }

  def bundle_with(components, **attributes)
    build(:product_bundle, store: store, components: components, **attributes)
  end

  it 'is a composition: it says which variants, in what quantity, form a set' do
    bundle = bundle_with({ tea => 1, cup => 2 })

    expect(bundle.save).to be(true)
    expect(bundle.components.map(&:quantity)).to eq([1, 2])
    expect(bundle.variants).to contain_exactly(tea, cup)
  end

  # The bundle has no price of its own: both figures come from the components'
  # current prices, so a component moving upstream moves the bundle with it.
  describe 'price' do
    it 'sums what the components cost one by one' do
      expect(bundle_with({ tea => 1, cup => 2 }).goods_price).to eq(140)
    end

    it 'takes a fixed amount off' do
      bundle = bundle_with({ tea => 1, cup => 2 }, preferred_discount_kind: 'amount')
      bundle.preferred_discount_value = 20

      expect(bundle.price).to eq(120)
      expect(bundle.saving).to eq(20)
    end

    it 'takes a percentage off' do
      bundle = bundle_with({ tea => 1, cup => 2 }, preferred_discount_kind: 'percentage')
      bundle.preferred_discount_value = 25

      expect(bundle.price).to eq(105)
      expect(bundle.saving).to eq(35)
    end

    # A bundle cannot be priced below zero, whatever the merchant typed.
    it 'never saves more than the components cost' do
      bundle = bundle_with({ tea => 1 }, preferred_discount_kind: 'amount')
      bundle.preferred_discount_value = 999

      expect(bundle.saving).to eq(60)
      expect(bundle.price).to eq(0)
    end

    it 'refuses a discount rule it does not know' do
      bundle = bundle_with({ tea => 1 }, preferred_discount_kind: 'freeform')

      expect(bundle).not_to be_valid
      expect(bundle.errors[:preferred_discount_kind]).to be_present
    end
  end

  # The scarcest component, expressed in bundles: the number the client
  # compares a combo quantity against.
  describe 'availability' do
    def stock(variant, count)
      create(:stock_level, variant: variant, stock_location: Spree::StockLocation.first,
                           count_on_hand: count, backorderable: false, adjust_count_on_hand: false)
    end

    it 'answers how many sets the shelf can fill' do
      stock(tea, 5)
      stock(cup, 9)

      expect(bundle_with({ tea => 2, cup => 1 }).available_bundles).to eq(2)
    end

    it 'answers nothing when a component is gone' do
      stock(tea, 5)
      stock(cup, 0)

      expect(bundle_with({ tea => 1, cup => 1 }).available_bundles).to eq(0)
    end
  end

  describe 'validations' do
    it 'needs a title, and takes its slug from it' do
      bundle = build(:product_bundle, store: store, title: '双人下午茶套餐')

      expect(bundle.save).to be(true)
      expect(bundle.slug).to eq('双人下午茶套餐')
    end

    # A marketplace splits an order by seller, and a bundle's single price has
    # no home in that fan-out.
    it 'refuses components from two sellers' do
      first_seller = create(:seller, store: store)
      second_seller = create(:seller, store: store)
      first = create(:product, store: store, seller: first_seller).default_variant
      second = create(:product, store: store, seller: second_seller).default_variant

      bundle = bundle_with({ first => 1, second => 1 })

      expect(bundle).not_to be_valid
      expect(bundle.errors[:components]).to be_present
    end

    it 'holds one component once' do
      bundle = build(:product_bundle, store: store)
      bundle.components.build(variant: tea, quantity: 1)
      bundle.components.build(variant: tea, quantity: 2)

      expect(bundle).not_to be_valid
      expect(bundle.errors[:components]).to be_present
    end
  end

  describe '.with_component_variant' do
    it 'answers the bundles a goods belongs to' do
      mine = bundle_with({ tea => 1 }).tap(&:save!)
      bundle_with({ cup => 1 }).tap(&:save!)

      expect(described_class.with_component_variant(tea)).to contain_exactly(mine)
    end
  end
end
