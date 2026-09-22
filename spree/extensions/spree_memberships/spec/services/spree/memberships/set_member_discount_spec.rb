require 'spec_helper'

RSpec.describe Spree::Memberships::SetMemberDiscount do
  let(:store) { @default_store }
  let(:group) { create(:customer_group, store: store) }
  let(:tier) { create(:membership_tier_setting, customer_group: group) }

  it 'gives the tier a catalogue of its own, in effect' do
    result = described_class.call(tier_setting: tier, percentage: 10)

    expect(result).to be_success
    expect(result.value).to be_active
    expect(result.value).to be_a(Spree::Catalog)
  end

  it 'names the catalogue and its list after the tier' do
    catalog = described_class.call(tier_setting: tier, percentage: 10).value

    expect(catalog.name).to include(tier.name)
    expect(catalog.price_list.name).to include(tier.name)
  end

  it 'prices through an owned automatic list, as a percentage off the shelf price' do
    catalog = described_class.call(tier_setting: tier, percentage: 10).value
    list = catalog.price_list

    expect(list).to be_active
    expect(list.catalog_id).to eq(catalog.id)
    # A list's factor is `1 + percentage / 100`, so a discount is negative.
    expect(list.price_adjustment_percentage).to eq(-10)
    expect(list.adjustment_factor).to eq(0.9)
  end

  it 'shows the catalogue to the tier’s group and to nobody else' do
    catalog = described_class.call(tier_setting: tier, percentage: 10).value

    expect(catalog.catalog_assignments.map(&:assignable)).to eq([group])
  end

  # An empty assortment hides nothing, so the tier prices the whole shop rather
  # than curating it.
  it 'carries no assortment' do
    catalog = described_class.call(tier_setting: tier, percentage: 10).value

    expect(catalog.catalog_products).to be_empty
  end

  it 'moves the price when it is set again, rather than standing up a second catalogue' do
    first = described_class.call(tier_setting: tier, percentage: 10).value
    second = described_class.call(tier_setting: tier, percentage: 15).value

    expect(second.id).to eq(first.id)
    expect(second.price_list.price_adjustment_percentage).to eq(-15)
    expect(tier.catalog).to eq(first)
  end

  # Zero and nil are the operator taking the price away: the catalogue stops
  # applying, and what was set up survives for when it comes back.
  it 'takes the price out of effect on zero, keeping the setup' do
    catalog = described_class.call(tier_setting: tier, percentage: 10).value

    result = described_class.call(tier_setting: tier, percentage: 0)

    expect(result.value.id).to eq(catalog.id)
    expect(result.value).not_to be_active
    expect(result.value.price_list).to be_present
  end

  it 'brings the same catalogue back into effect' do
    first = described_class.call(tier_setting: tier, percentage: 10).value
    described_class.call(tier_setting: tier, percentage: nil)

    expect(described_class.call(tier_setting: tier, percentage: 10).value.id).to eq(first.id)
  end

  # A catalogue is store-scoped, so there has to be a store to stand it up in.
  it 'refuses a tier whose store cannot be reached' do
    allow(tier).to receive(:store).and_return(nil)

    expect(described_class.call(tier_setting: tier, percentage: 10)).to be_failure
  end

  def client_name
    tier.reload.name
  end
end
