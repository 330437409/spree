module Spree
  module MembershipKinds
    # Buying a term: the `vip` kind of a scenario purchase
    # (docs/plans/6.1-scenario-purchases.md).
    #
    # What a purchase costs is the price of the variant the tier's SKU names, in
    # the currency the customer is shopping in. The tier is what the operator
    # prices and lists — it stays a product with a price for exactly that reason —
    # and the SKU is the link between the two, which is why the tier settings row
    # carries it (docs/plans/6.1-membership-tiers-and-rights.md).
    #
    # Settling it issues one dormant card owned by the buyer, and nothing else.
    # Whether the purchase was for the buyer or for somebody else makes no
    # difference here: giving a card away is the transfer the wallet already has,
    # and activating it is a later door that starts the term.
    class Vip < Spree::ScenarioOrders::Kind
      # Fixed rather than derived — the default is the class name's, and renaming
      # the class must not change what a client sends.
      def self.api_type
        'vip'
      end

      # @param context [Hash] the purchase's own vocabulary, stored verbatim
      # @return [BigDecimal, nil] nil when there is nothing to sell, which the
      #   frame renders as "not for sale" rather than as a free term
      def self.price(context)
        amount_for(tier_for(context))
      end

      # The packages on sale: every tier this store sells a term of, at the price
      # it is sold for. This is what the client's buy page renders, and it is the
      # kind's own read — a package id, a site and a referral code mean nothing to
      # the frame.
      #
      # @return [Array<Hash>]
      def self.offers(_context = {})
        tiers = Spree::MembershipTierSetting.for_store(Spree::Current.store).order(:rank)

        tiers.filter_map do |tier|
          amount = amount_for(tier)
          next if amount.nil?

          {
            'tier_id' => tier.prefixed_id,
            'name' => tier.name,
            'amount' => amount.to_s,
            'currency' => currency,
            'validity_days' => tier.validity_days,
            'auto_renew' => tier.auto_renew
          }
        end
      end

      # A purchase needs a buyer to own the card it issues. Whether they may hold
      # two of one tier is not a question here: a second card is refused at
      # activation, and the client warns before the purchase.
      def self.eligible?(customer)
        customer.present?
      end

      # @param scenario_order [Spree::ScenarioOrder]
      # @return [Spree::ServiceModule::Result] the card it issued, or the
      #   existing one when the settlement is retried
      def self.issue!(scenario_order)
        return refuse(scenario_order, :buyer_missing) if scenario_order.customer.nil?

        tier = tier_for(scenario_order.payload, store: scenario_order.store)
        return refuse(scenario_order, :tier_unknown) if tier.nil?

        accept(card_for(scenario_order, tier))
      end

      # A refund, which is the only thing that takes an issued entitlement back:
      # the card is voided and the term it started ends, by the same workflow the
      # operator's own void runs.
      def self.reverse!(scenario_order)
        card = Spree::MembershipCard.find_by(scenario_order: scenario_order)
        return refuse(scenario_order, :nothing_issued) if card.nil?

        Spree::MembershipCards::Recycle.call(card: card)
      end

      class << self
        private

        # @param context [Hash] the purchase's payload, whose keys arrive as
        #   strings: it is stored as JSON
        # @return [Spree::MembershipTierSetting, nil]
        def tier_for(context, store: Spree::Current.store)
          id = (context || {}).with_indifferent_access[:tier_id]
          return if id.blank?

          Spree::MembershipTierSetting.for_store(store).find_by_prefix_id(id)
        end

        # Through the lineage rather than a bare lookup: a SKU belongs to a
        # product in this store, and the relation says so. Core validates a SKU
        # globally today, so nothing else can hold this one — the scope is what
        # keeps it that way rather than something to rely on.
        #
        # The base price, deliberately: what a term costs is what the operator
        # listed it at, and a member price is a discount on the products a tier
        # buys rather than on the membership itself.
        #
        # @return [BigDecimal, nil] nil when there is nothing to sell at
        def amount_for(tier)
          return if tier.nil? || tier.sku.blank?

          amount = Spree::Variant.joins(:product).merge(Spree::Product.for_store(tier.store)).
                   find_by(sku: tier.sku)&.amount_in(currency)

          amount if amount.present? && amount.positive?
        end

        # The window to activate or give the card away in: a term's length from
        # the day it was bought. Nothing else says when a card goes stale, and the
        # tier already carries the length — an open-ended tier has none, and its
        # cards have no deadline either.
        def card_for(scenario_order, tier)
          Spree::MembershipCard.find_or_create_by(scenario_order: scenario_order) do |card|
            card.store = scenario_order.store
            card.customer = scenario_order.customer
            card.customer_group = tier.customer_group
            card.source = 'purchase'
            card.activates_before = tier.term_length&.from_now
          end
        rescue ActiveRecord::RecordNotUnique
          # Two settlements that raced past the frame's compare-and-set: the index
          # refused the second card, and the first is the answer.
          Spree::MembershipCard.find_by!(scenario_order: scenario_order)
        end

        # The currency a purchase is priced in falls back to the store's own,
        # which is the rule the frame sets for the row it writes.
        def currency
          Spree::Current.currency.presence || Spree::Current.store&.default_currency
        end
      end
    end
  end
end
