# A tier that can actually be bought: the settings row, and the variant its SKU
# names at one price. What "a term costs 365" means in specs, in one place.
RSpec.shared_context 'a priced tier' do
  let(:group) { create(:customer_group, store: store) }
  let(:tier_sku) { 'VIP-365' }
  let(:tier) do
    create(:membership_tier_setting, customer_group: group, rank: 1, validity_days: 365, sku: tier_sku)
  end

  before do
    tier
    create(:variant, product: create(:product, store: store), sku: tier_sku, price: 365)
  end
end
