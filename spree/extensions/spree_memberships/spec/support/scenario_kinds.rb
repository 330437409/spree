# A kind for the specs that need a purchase to point at — what issued a card.
#
# The `vip` kind itself arrives with the purchase that prices and issues it;
# this is not it, and exists so a factory-built scenario order can name a kind
# that is registered (docs/plans/6.1-membership-tiers-and-rights.md).
module Spree
  module ScenarioOrders
    module TestKinds
      class CardPurchase < Spree::ScenarioOrders::Kind
        def self.api_type
          'card_purchase'
        end

        def self.price(context)
          context['amount'] || 100
        end

        def self.eligible?(customer)
          customer.present?
        end

        def self.issue!(scenario_order)
          accept(scenario_order)
        end

        def self.reverse!(scenario_order)
          accept(scenario_order)
        end
      end
    end
  end
end

SpreeScenarioPurchases.scenario_order_kinds << Spree::ScenarioOrders::TestKinds::CardPurchase
