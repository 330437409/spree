require 'spec_helper'

RSpec.describe Spree::PointProduct, type: :model do
  let(:store) { @default_store }

  it 'registers its kinds, each with its own name on the wire' do
    expect(SpreePoints.point_product_types.map(&:api_type)).to contain_exactly('coupon', 'good', 'vip_card')
    expect(Spree::PointProduct.find_by_api_type('vip_card')).to eq(Spree::PointProducts::VipCard)
  end

  it 'refuses a name or a price that is not one' do
    expect(build(:point_product, store: store, name: nil)).not_to be_valid
    expect(build(:point_product, store: store, points: -1)).not_to be_valid
    expect(build(:point_product, store: store, money: -1)).not_to be_valid
    expect(build(:point_product, store: store, stock: -1)).not_to be_valid
  end

  it 'offers only the two audiences an operator may name' do
    expect(build(:point_product, store: store, limit_user_type: 'anyone')).not_to be_valid
    expect(create(:point_product, store: store, limit_user_type: 'vip_user')).to be_valid
  end

  describe 'what each kind must carry' do
    it 'a coupon good needs the campaign it issues from' do
      expect(build(:point_coupon_product, store: store)).not_to be_valid
    end

    it 'a card good needs the group it issues' do
      expect(build(:point_vip_card_product, store: store, customer_group: create(:customer_group))).to be_valid
    end

    it 'a shippable good needs the variant it puts on an order' do
      expect(build(:point_product, store: store, variant: nil)).not_to be_valid
    end
  end

  describe 'the shelf' do
    let!(:store_wide) { create(:point_product, store: store, seller: nil, position: 2) }
    let!(:first) { create(:point_product, store: store, position: 1, category: 'cups') }
    let!(:sellers) { create(:point_product, store: store, seller: create(:seller, store: store), position: 3) }

    it 'orders by position' do
      expect(described_class.where(store: store).ordered.first).to eq(first)
    end

    it 'narrows to one operator label' do
      expect(described_class.for_category('cups')).to contain_exactly(first)
    end

    # A seller's shelf shows its own goods beside the store's, never another
    # seller's.
    it 'narrows a seller shelf to what that seller offers' do
      other = create(:point_product, store: store, seller: create(:seller, store: store))

      expect(described_class.for_seller(sellers.seller)).to include(store_wide, sellers)
      expect(described_class.for_seller(sellers.seller)).not_to include(other)
    end

    it 'tells whether a redemption can issue one' do
      expect(sellers).to be_in_stock
      expect(create(:point_product, store: store, stock: 0)).not_to be_in_stock
    end
  end
end
