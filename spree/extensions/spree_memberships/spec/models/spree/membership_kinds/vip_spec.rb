require 'spec_helper'

RSpec.describe Spree::MembershipKinds::Vip do
  let(:store) { @default_store }
  let(:buyer) { create(:customer) }
  let(:group) { create(:customer_group, store: store) }
  let(:tier) do
    create(:membership_tier_setting, customer_group: group, rank: 1, validity_days: 365, sku: 'VIP-365')
  end

  before do
    Spree::Current.store = store
    tier
    create(:variant, product: create(:product, store: store), sku: 'VIP-365', price: 365)
  end

  # The kind's own vocabulary: a package, and which tier it is.
  def context(**overrides)
    { 'tier_id' => tier.prefixed_id }.merge(overrides)
  end

  def order(**overrides)
    create(:scenario_order, store: store, customer: buyer, kind: 'vip', **overrides)
  end

  it 'is the kind a client addresses by name' do
    expect(described_class.api_type).to eq('vip')
    expect(Spree::ScenarioOrder.kind_for('vip')).to eq(described_class)
  end

  describe 'what it costs' do
    it 'prices the tier by the variant its SKU names' do
      expect(described_class.price(context)).to eq(365)
    end

    it 'has nothing to sell when the tier names no variant' do
      tier.update!(sku: nil)

      expect(described_class.price(context)).to be_nil
    end

    it 'has nothing to sell when the variant carries no price' do
      Spree::Variant.find_by(sku: 'VIP-365').prices.delete_all

      expect(described_class.price(context)).to be_nil
    end

    it 'has nothing to sell for a tier of another store' do
      other = create(:membership_tier_setting, rank: 2, sku: 'VIP-365',
                                               customer_group: create(:customer_group, store: create(:store)))

      expect(described_class.price('tier_id' => other.prefixed_id)).to be_nil
    end

  end

  describe 'the packages on sale' do
    it 'lists every tier this store prices, with what it costs' do
      expect(described_class.offers).to contain_exactly(
        include('tier_id' => tier.prefixed_id, 'name' => tier.name, 'amount' => '365.0',
                'currency' => 'USD', 'validity_days' => 365)
      )
    end

    it 'leaves out a tier nobody priced' do
      create(:membership_tier_setting, customer_group: create(:customer_group, store: store),
                                       rank: 2, sku: 'VIP-NONE')

      expect(described_class.offers.map { |offer| offer['tier_id'] }).to eq([tier.prefixed_id])
    end
  end

  it 'is bought by a signed-in buyer' do
    expect(described_class.eligible?(buyer)).to be(true)
    expect(described_class.eligible?(nil)).to be(false)
  end

  describe 'what settling it issues' do
    it 'issues one dormant card, owned by the buyer, with the window to activate it' do
      result = described_class.issue!(order(payload: context))

      expect(result).to be_success
      card = result.value
      expect(card).to be_dormant
      expect(card.store).to eq(store)
      expect(card.customer).to eq(buyer)
      expect(card.customer_group).to eq(group)
      expect(card.source).to eq('purchase')
      expect(card.activates_before).to be_within(1.minute).of(365.days.from_now)
    end

    # The settlement retries, and the webhook arrives more than once.
    it 'answers a retry with the card it already issued' do
      scenario_order = order(payload: context)
      first = described_class.issue!(scenario_order).value

      expect(described_class.issue!(scenario_order).value.id).to eq(first.id)
      expect(Spree::MembershipCard.count).to eq(1)
    end

    it 'leaves a card for an open-ended tier with no deadline' do
      tier.update!(validity_days: nil)

      expect(described_class.issue!(order(payload: context)).value.activates_before).to be_nil
    end

    it 'refuses a tier that is no longer sold' do
      tier.destroy

      expect(described_class.issue!(order(payload: context))).to be_failure
      expect(Spree::MembershipCard.count).to eq(0)
    end
  end

  describe 'a refund' do
    it 'voids the card and ends the term it started' do
      scenario_order = order(payload: context)
      card = described_class.issue!(scenario_order).value
      Spree::MembershipCards::Activate.call(card: card, customer: buyer)

      expect(described_class.reverse!(scenario_order)).to be_success
      expect(card.reload).to be_recycled
      expect(card.membership.reload).not_to be_active
    end

    it 'refuses a purchase that issued nothing' do
      expect(described_class.reverse!(order(payload: context))).to be_failure
    end
  end
end
