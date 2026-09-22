module Spree
  module ScenarioOrders
    # Closes the purchases whose window has passed without a settlement.
    #
    # A status rather than a derived fact, because the client's unpaid screens
    # read it: `getNoOvertimePaymentGoods` and `getOvertimePaymentInfo` are
    # scopes over this state. Run it from cron — `rake spree_scenario_orders:expire`
    # — so nothing about a request depends on it having run.
    class Expire
      prepend Spree::ServiceModule::Base

      # @return [Spree::ServiceModule::Result] value is how many rows moved
      def call(now: Time.current)
        moved = Spree::ScenarioOrder.unsettled.lapsed.update_all(status: 'expired', updated_at: now)

        success(moved)
      end
    end
  end
end
