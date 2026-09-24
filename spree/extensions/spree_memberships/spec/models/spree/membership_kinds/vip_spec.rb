require 'spec_helper'

RSpec.describe Spree::MembershipKinds::Vip do
  include_context 'a priced tier'

  let(:store) { @default_store }
  let(:buyer) { create(:customer) }

  before { Spree::Current.store = store }

  # The kind's own vocabulary: which package, and nothing else it needs.
  def purchase_context(**overrides)
    { 'tier_id' => tier.prefixed_id }.merge(overrides)
  end

  def purchase(**overrides)
    create(:scenario_order, store: store, customer: buyer, kind: 'vip', **overrides)
  end

  it 'is the kind a client addresses by name' do
    expect(described_class.api_type).to eq('vip')
    expect(Spree::ScenarioOrder.kind_for('vip')).to eq(described_class)
  end

  describe 'what it costs' do
    it 'prices the tier by the variant its SKU names' do
      expect(described_class.price(purchase_context)).to eq(365)
    end

    it 'has nothing to sell when the tier names no variant' do
      tier.update!(sku: nil)

      expect(described_class.price(purchase_context)).to be_nil
    end

    it 'has nothing to sell when the variant carries no price' do
      Spree::Variant.find_by(sku: 'VIP-365').prices.delete_all

      expect(described_class.price(purchase_context)).to be_nil
    end

    # Deliberately the SKU *this* store's variant carries: were the tier looked up
    # outside the store, it would be priced by a variant that is not its own.
    it 'has nothing to sell for a tier of another store' do
      other = create(:membership_tier_setting, rank: 2, sku: tier_sku,
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

  # The client's own warning before it takes the money (vip/addOrderCheck): what
  # the terms a customer already holds do to the one they are about to buy.
  describe 'the pre-purchase warning' do
    def checks(for_tier = tier)
      described_class.purchase_checks(tier: for_tier, customer: buyer, store: store)
    end

    it 'warns about nothing when the customer holds nothing' do
      expect(checks).to eq([])
    end

    # The same tier's own live term is extended rather than waited out: the
    # customer keeps what they hold and no right of theirs changes.
    it 'warns about nothing for the tier the customer already holds' do
      create(:membership, customer: buyer, customer_group: group)

      expect(checks).to eq([])
    end

    it 'names the term the purchase waits behind, and when it ends' do
      held = create(:membership, customer: buyer, customer_group: another_tier.customer_group,
                                 ends_at: 3.months.from_now)

      expect(checks).to contain_exactly(
        'kind' => 'overlap',
        'tier_name' => held.customer_group.name,
        'held_until' => held.ends_at
      )
    end

    # A term queues behind every live one, so a customer who bought two tiers
    # ahead waits for the later of them rather than for the running one.
    it 'waits for the last term held, not the running one' do
      running = create(:membership, customer: buyer, customer_group: another_tier.customer_group,
                                    ends_at: 3.months.from_now)
      later = create(:membership, customer: buyer, customer_group: another_tier.customer_group,
                                  status: 'pending', starts_at: running.ends_at, ends_at: 6.months.from_now)

      expect(checks).to contain_exactly(
        'kind' => 'overlap',
        'tier_name' => later.customer_group.name,
        'held_until' => later.ends_at
      )
    end

    # A live term with no end refuses the activation outright, and a customer
    # would otherwise find that out after paying for the card.
    it 'warns that a term held with no end refuses the purchase' do
      held = create(:membership, customer: buyer, customer_group: another_tier.customer_group, ends_at: nil)

      expect(checks).to contain_exactly('kind' => 'open_ended', 'tier_name' => held.customer_group.name)
    end

    it 'warns about nothing for a term that has ended' do
      create(:membership, customer: buyer, customer_group: another_tier.customer_group,
                          status: 'expired', starts_at: 2.days.ago, ends_at: 1.day.ago)

      expect(checks).to eq([])
    end

    # A customer is installation-wide and a term is not. What they hold in
    # another store is that store's business: it must not decide what this
    # store's purchase does, nor be named to this store's buyer.
    it 'ignores a term the customer holds against another store’s tier' do
      elsewhere = create(:membership_tier_setting, customer_group: create(:customer_group, store: create(:store)))
      create(:membership, store: elsewhere.store, customer: buyer,
                          customer_group: elsewhere.customer_group, ends_at: 3.months.from_now)

      expect(checks).to eq([])
    end

    # A retired tier soft-deletes its settings row and leaves its group — so the
    # group is what a name is read from, or the client would render its warning
    # around a nameless tier.
    it 'names a tier the operator has retired since the term was granted' do
      held = create(:membership, customer: buyer, customer_group: another_tier.customer_group,
                                 ends_at: 3.months.from_now)
      held.tier_setting.destroy

      expect(checks).to contain_exactly(include('tier_name' => held.customer_group.name))
    end
  end

  describe 'what settling it issues' do
    it 'issues one dormant card, owned by the buyer, with the window to activate it' do
      result = described_class.issue!(purchase(payload: purchase_context))

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
      scenario_order = purchase(payload: purchase_context)
      first = described_class.issue!(scenario_order).value

      expect(described_class.issue!(scenario_order).value.id).to eq(first.id)
      expect(Spree::MembershipCard.count).to eq(1)
    end

    it 'leaves a card for an open-ended tier with no deadline' do
      tier.update!(validity_days: nil)

      expect(described_class.issue!(purchase(payload: purchase_context)).value.activates_before).to be_nil
    end

    it 'refuses a tier that is no longer sold' do
      tier.destroy

      expect(described_class.issue!(purchase(payload: purchase_context))).to be_failure
      expect(Spree::MembershipCard.count).to eq(0)
    end
  end

  describe 'a refund' do
    it 'voids the card and ends the term it started' do
      scenario_order = purchase(payload: purchase_context)
      card = described_class.issue!(scenario_order).value
      Spree::MembershipCards::Activate.call(card: card, customer: buyer)

      expect(described_class.reverse!(scenario_order)).to be_success
      expect(card.reload).to be_recycled
      expect(card.membership.reload).not_to be_active
    end

    it 'refuses a purchase that issued nothing' do
      expect(described_class.reverse!(purchase(payload: purchase_context))).to be_failure
    end

    # The purchase nobody activated: the sweep has already taken the card, and
    # the refund still has to be answerable rather than refused.
    it 'answers a refund for a card the sweep expired' do
      scenario_order = purchase(payload: purchase_context)
      card = described_class.issue!(scenario_order).value
      card.update!(activates_before: 1.hour.ago)
      Spree::MembershipCards::Expire.call(card: card)

      expect(card.reload).to be_expired
      expect(described_class.reverse!(scenario_order)).to be_success
    end

    # A refund can be retried the way a settlement can, and taking the card back
    # twice must not take its term back twice.
    it 'answers a repeated refund with the card it already voided' do
      scenario_order = purchase(payload: purchase_context)
      card = described_class.issue!(scenario_order).value
      described_class.reverse!(scenario_order)

      expect(described_class.reverse!(scenario_order)).to be_success
      expect(card.reload).to be_recycled
    end
  end
end
