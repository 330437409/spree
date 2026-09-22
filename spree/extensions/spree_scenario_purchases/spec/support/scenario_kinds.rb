# A kind that only prices and counts, so the frame's own behaviour — pricing
# through a kind, issuing on settlement, reversing on refund — can be exercised
# before any owning plan has registered a real one. Registered here rather than
# in a hook because a factory-built row has to name a kind that exists.
module Spree
  module ScenarioOrders
    module TestKinds
      class Simple < Spree::ScenarioOrders::Kind
        def self.api_type
          'simple'
        end

        def self.price(context)
          context['amount'] || 10
        end

        def self.eligible?(customer)
          customer.present?
        end

        def self.issue!(scenario_order)
          scenario_order.metadata['issued'] = scenario_order.metadata.fetch('issued', 0) + 1
          scenario_order.save!

          accept(scenario_order)
        end

        def self.reverse!(scenario_order)
          scenario_order.metadata['reversed'] = true
          scenario_order.save!

          accept(scenario_order)
        end
      end

      class Never < Spree::ScenarioOrders::Kind
        def self.api_type
          'never'
        end

        def self.price(_context)
          5
        end

        def self.eligible?(_customer)
          false
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

[
  Spree::ScenarioOrders::TestKinds::Simple,
  Spree::ScenarioOrders::TestKinds::Never
].each do |kind|
  SpreeScenarioPurchases.scenario_order_kinds << kind unless SpreeScenarioPurchases.scenario_order_kinds.include?(kind)
end
