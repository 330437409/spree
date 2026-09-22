module Spree
  module ScenarioOrders
    # Abandons a purchase the customer did not pay for. Nothing was granted, so
    # there is nothing to take back — the session is simply called off.
    class Cancel
      prepend Spree::ServiceModule::Base

      # @return [Spree::ServiceModule::Result] value is the scenario order
      def call(scenario_order:)
        return failure(scenario_order, :already_settled) if scenario_order.paid?
        return failure(scenario_order, :already_canceled) if scenario_order.canceled?

        Spree::ScenarioOrder.transaction(requires_new: true) do
          scenario_order.payment_sessions.each(&:cancel)
          scenario_order.update!(status: 'canceled')
        end

        success(scenario_order.reload)
      end
    end
  end
end
