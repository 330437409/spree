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
      # The things a purchase can be warned about, named once: what the buyer is
      # told before they pay is what the client switches on.
      OVERLAP_CHECK = 'overlap'.freeze
      BLOCKED_CHECK = 'open_ended'.freeze
      NO_TIME_CHECK = 'adds_no_time'.freeze
      CHECK_KINDS = [OVERLAP_CHECK, BLOCKED_CHECK, NO_TIME_CHECK].freeze

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
        store = Spree::Current.store
        tiers = Spree::MembershipTierSetting.for_store(store).includes(:customer_group).order(:rank)

        tiers.filter_map do |tier|
          amount = amount_for(tier, store: store)
          next if amount.nil?

          {
            'tier_id' => tier.prefixed_id,
            'name' => tier.name,
            'amount' => amount.to_s,
            'currency' => Spree::Current.currency,
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

      # What buying this tier means for the terms the buyer already holds — the
      # client's pre-purchase warning (`vip/addOrderCheck`), asked before the
      # money rather than after it.
      #
      # A read, not a second purchase, and advisory: the client buys on any
      # answer, so nothing here refuses. What it can say is which of the two
      # facts the buyer is walking into — that the term they are buying waits
      # behind one they already hold, or that a term held with no end refuses
      # the card once they have paid for it.
      #
      # @param tier [Spree::MembershipTierSetting] the package being bought
      # @param customer [Object] the buyer
      # @param store [Spree::Store] the store selling it, whose terms are the
      #   ones this warning is about
      # @return [Array<Hash>] empty when there is nothing to warn about
      def self.purchase_checks(tier:, customer:, store:)
        arrival = Spree::Membership.arrival_for(customer: customer,
                                                customer_group_id: tier.customer_group_id,
                                                store: store)

        # The same tier's own live term is extended rather than waited out: the
        # buyer keeps what they hold and no right of theirs changes — unless that
        # term has no end to extend, which is a purchase that would add nothing
        # and take the money anyway. A tier an operator sells without a length is
        # a term nobody has to renew, so saying so before the purchase is the only
        # place left to say it.
        if arrival[:same_tier].present?
          return [] if arrival[:same_tier].ends_at.present?

          return [{ 'kind' => NO_TIME_CHECK, 'tier_name' => tier_name_of(arrival[:same_tier]) }]
        end

        if arrival[:blocked_by].present?
          [{ 'kind' => BLOCKED_CHECK, 'tier_name' => tier_name_of(arrival[:blocked_by]) }]
        elsif arrival[:waits_behind].present?
          [{ 'kind' => OVERLAP_CHECK,
             'tier_name' => tier_name_of(arrival[:waits_behind]),
             # The instant the new term begins: the held term's end, or this
             # moment when that end has gone by. One reader, so what the buyer is
             # warned about and what the activation starts are the same instant.
             'held_until' => Spree::Membership.arrival_at(arrival[:waits_behind]) }]
        else
          []
        end
      end

      # @param scenario_order [Spree::ScenarioOrder]
      # @return [Spree::ServiceModule::Result] the card it issued, or the
      #   existing one when the settlement is retried
      def self.issue!(scenario_order)
        return refuse(scenario_order, :buyer_missing) if scenario_order.customer.nil?

        tier = tier_for(scenario_order.payload, store: scenario_order.store)
        return refuse(scenario_order, :tier_unknown) if tier.nil?

        card = card_for(scenario_order, tier)
        return refuse(scenario_order, :card_invalid) if card.nil?

        accept(card)
      end

      # A refund, which is the only thing that takes an issued entitlement back:
      # the card is voided and the term it started ends, by the same workflow the
      # operator's own void runs.
      #
      # A card the sweep already expired has nothing to take back — nobody
      # activated it, so the deadline passing *was* its reversal — and refusing
      # the refund would leave a paid purchase with no way to answer it.
      def self.reverse!(scenario_order)
        card = Spree::MembershipCard.find_by(scenario_order: scenario_order)
        return refuse(scenario_order, :nothing_issued) if card.nil?
        return accept(card) if card.expired?

        Spree::MembershipCards::Recycle.call(card: card)
      end

      class << self
        private

        # The tier a term holds, under the name the operator gave it: the tier
        # set is their data, so the client renders the name rather than mapping
        # a key of its own.
        #
        # Read from the term's group rather than through the settings row, which
        # is soft-deleted when the operator retires a tier: a member holding a
        # term of one would otherwise be warned about a nameless tier.
        #
        # @return [String, nil]
        def tier_name_of(term)
          term.customer_group&.name
        end

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
        def amount_for(tier, store: Spree::Current.store)
          return if tier.nil? || tier.sku.blank?

          amount = Spree::Variant.joins(:product).merge(Spree::Product.for_store(store)).
                   find_by(sku: tier.sku)&.amount_in(Spree::Current.currency)

          amount if amount.present? && amount.positive?
        end

        # `find_or_create_by!` rather than its quieter twin: that one saves
        # through `create_or_find_by`, which *returns an unpersisted card* when the
        # model refuses it — the settlement would record a success for a purchase
        # that issued nothing and no operator would see a reason. This way the
        # refusal lands in the row they reconcile. A concurrent insert is still a
        # non-event: `create_or_find_by` retries the find by itself.
        #
        # @return [Spree::MembershipCard, nil]
        def card_for(scenario_order, tier)
          Spree::MembershipCard.find_or_create_by!(scenario_order: scenario_order) do |card|
            card.store = scenario_order.store
            card.customer = scenario_order.customer
            card.customer_group = tier.customer_group
            card.source = 'purchase'
            # The window to activate or give it away in: a term's length from the
            # day it was bought. Nothing else says when a card goes stale, and the
            # tier already carries the length — an open-ended tier has none, and
            # its cards have no deadline either.
            card.activates_before = tier.term_length&.from_now
          end
        rescue ActiveRecord::RecordInvalid
          nil
        end
      end
    end
  end
end
