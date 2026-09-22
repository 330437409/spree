module Spree
  module ScenarioOrders
    # The purchase is paid for, so the kind hands over what was bought.
    #
    # Reached twice by design: the gateway's webhook and the customer's
    # synchronous return both settle the same session, and a webhook can arrive
    # more than once. The status transition is what makes the second arrival a
    # no-op, and a kind's own `issue!` is idempotent behind it.
    class Settle
      prepend Spree::ServiceModule::Base

      # @return [Spree::ServiceModule::Result] value is the scenario order
      def call(scenario_order:)
        return failure(scenario_order, :already_settled) if scenario_order.paid?

        kind_class = scenario_order.kind_class
        return failure(scenario_order, :unknown_kind) if kind_class.nil?

        scenario_order.update!(status: 'paid')

        issued = kind_class.issue!(scenario_order)
        return failure(scenario_order, issued.error) if issued.respond_to?(:failure?) && issued.failure?

        success(scenario_order.reload)
      end
    end
  end
end
