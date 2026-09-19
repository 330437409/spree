require 'spec_helper'

RSpec.describe Spree::PriceContexts::ProductSellers do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }
  let(:other_seller) { create(:seller, :approved, store: store) }
  let(:product) { create(:product, store: store) }

  before { product.variants.destroy_all }

  def sellers_for(record)
    described_class.call(product: record.reload)
  end

  it 'answers nothing for a product only the operator sells' do
    create(:variant, product: product, sku: 'O-1', price: 10)

    expect(sellers_for(product)).to be_empty
  end

  it 'answers the sellers of the variants a shopper could buy from' do
    create(:variant, product: product, seller: seller, sku: 'S-1', price: 10)
    create(:variant, product: product, seller: other_seller, sku: 'S-2', price: 20)

    expect(sellers_for(product)).to contain_exactly(seller, other_seller)
  end

  it 'answers a seller once however many variants they hold' do
    create(:variant, product: product, seller: seller, sku: 'S-1', price: 10)
    create(:variant, product: product, seller: seller, sku: 'S-2', price: 20)

    expect(sellers_for(product).to_a).to eq([seller])
  end

  it 'leaves out a seller who is not selling today' do
    [create(:seller, :suspended, store: store), create(:seller, :onboarding, store: store),
     create(:seller, :on_holiday, store: store)].each_with_index do |unavailable, index|
      create(:variant, product: product, seller: unavailable, sku: "X-#{index}", price: 1)
    end
    create(:variant, product: product, seller: seller, sku: 'S-9', price: 90)

    expect(sellers_for(product)).to contain_exactly(seller)
  end

  # A seller-owned listing resolves every variant to its owner, so the answer is
  # that owner rather than whoever the variants happen to name.
  it 'answers the owner of a seller-owned listing' do
    owned = create(:product, store: store, seller: seller)
    owned.variants.destroy_all
    create(:variant, product: owned, sku: 'O-1', price: 10)

    expect(sellers_for(owned)).to contain_exactly(seller)
  end

  it 'answers nothing for a seller-owned listing whose owner is not selling today' do
    owned = create(:product, store: store, seller: create(:seller, :suspended, store: store))
    owned.variants.destroy_all
    create(:variant, product: owned, sku: 'O-1', price: 10)

    expect(sellers_for(owned)).to be_empty
  end
end
