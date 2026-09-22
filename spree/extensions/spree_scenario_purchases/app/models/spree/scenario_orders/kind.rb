module Spree
  module ScenarioOrders
    # What a kind of scenario purchase answers, and the whole of the contract:
    # what it costs, who may buy it, what settling it issues, and what a refund
    # takes back.
    #
    # A kind is a class the plan that owns the thing registers —
    # `SpreeScenarioPurchases.scenario_order_kinds << SpreeMembership::Kinds::Vip`
    # — and the row it is bought through names it by `api_type`. The frame
    # performs none of the four: it prices nothing, grants nothing and reverses
    # nothing, because each belongs to the plan that owns the entitlement
    # (docs/plans/6.1-scenario-purchases.md).
    class Kind
      # The name the row stores and a picker reads. Derived from the class the
      # way {Spree::Base.api_type} derives it, so a kind that renames its class
      # pins this rather than changing what every stored row means.
      #
      # @return [String]
      def self.api_type
        to_s.demodulize.underscore
      end

      # @return [String] the name an operator and a client read
      def self.human_name
        Spree.t("scenario_order_kinds.#{api_type}.name", default: to_s.demodulize.titleize)
      end

      # What one costs, in the store's currency, for the context the client
      # sent. A kind that cannot price this context refuses rather than
      # answering zero.
      #
      # @param context [Hash]
      # @return [Numeric, nil]
      def self.price(_context)
        raise NotImplementedError
      end

      # What this kind offers, as `pay_config` lists it — the terms, the
      # packages, the amounts the client shows before anything is bought. A
      # kind with nothing to list says so by answering nothing.
      #
      # @param context [Hash]
      # @return [Array<Hash>]
      def self.offers(_context = {})
        []
      end

      # Whether this customer may buy one right now — a term that would
      # overlap, a pack their tier does not allow.
      #
      # @param customer [Spree.user_class, nil]
      # @return [Boolean]
      def self.eligible?(_customer)
        true
      end

      # Issues what was bought, idempotently: a gateway can and will deliver the
      # same notification more than once, and a retried settlement must not
      # grant twice.
      #
      # @param scenario_order [Spree::ScenarioOrder]
      # @return [Spree::ServiceModule::Result]
      def self.issue!(_scenario_order)
        raise NotImplementedError
      end

      # Takes back what {.issue!} granted, when the purchase is refunded. Only
      # the kind knows how: points reverse through the ledger, a coupon through
      # its holding, a membership by the term it granted.
      #
      # @param scenario_order [Spree::ScenarioOrder]
      # @return [Spree::ServiceModule::Result]
      def self.reverse!(_scenario_order)
        raise NotImplementedError
      end

      # The answer a kind gives when it has done what it was asked, so a kind's
      # own service and the frame speak the same shape.
      #
      # @param scenario_order [Spree::ScenarioOrder]
      # @return [Spree::ServiceModule::Result]
      def self.accept(scenario_order)
        Spree::ServiceModule::Result.new(true, scenario_order)
      end

      # …and when it will not: the reason is what the caller is told.
      #
      # @param scenario_order [Spree::ScenarioOrder]
      # @param reason [Symbol, String]
      # @return [Spree::ServiceModule::Result]
      def self.refuse(scenario_order, reason)
        Spree::ServiceModule::Result.new(false, scenario_order, Spree::ServiceModule::ResultError.new(reason))
      end
    end
  end
end
