module Spree
  module ScenarioOrders
    # The purchase is paid for, so the kind hands over what was bought.
    #
    # Reached twice by design: the gateway's webhook and the customer's
    # synchronous return both settle the same session, and a webhook can arrive
    # more than once. The status transition is what makes the second arrival a
    # no-op, and a kind's own `issue!` is idempotent behind it.
    #
    # The money arriving is a fact and is recorded first: an issuance that then
    # fails — a kind whose gem is not deployed, a refusal of its own — leaves a
    # paid purchase an operator has to reconcile rather than a purchase that
    # looks unpaid while the customer has been charged. It is reported, and the
    # reason is kept on the row so a reconciliation starts from what went wrong.
    class Settle
      prepend Spree::ServiceModule::Base

      # @return [Spree::ServiceModule::Result] value is the scenario order
      def call(scenario_order:)
        return failure(scenario_order, :already_settled) unless claim(scenario_order)

        issue(scenario_order.reload)
      end

      private

      # Marks the purchase paid, and only if it was still waiting to be: a
      # cancel or a lapse that got there first, or a second settlement arriving
      # beside the first, loses the race rather than taking the row.
      #
      # @return [Boolean]
      def claim(scenario_order)
        Spree::ScenarioOrder.where(id: scenario_order.id, status: %w[pending paying]).
          update_all(status: 'paid', updated_at: Time.current) == 1
      end

      # @return [Spree::ServiceModule::Result]
      def issue(scenario_order)
        kind_class = scenario_order.kind_class
        return record_failure(scenario_order, :unknown_kind) if kind_class.nil?

        issued = kind_class.issue!(scenario_order)
        return record_failure(scenario_order, issued.error) if issued.failure?

        success(scenario_order.reload)
      end

      # @return [Spree::ServiceModule::Result]
      def record_failure(scenario_order, error)
        reason = error.respond_to?(:value) ? error.value : error

        scenario_order.update!(metadata: scenario_order.metadata.merge('issuance_failed' => reason.to_s))
        Rails.error.report(
          Spree::ScenarioOrders::IssuanceError.new("#{scenario_order.prefixed_id} was paid but not issued: #{reason}"),
          context: { scenario_order_id: scenario_order.id, kind: scenario_order.kind },
          source: 'spree.scenario_orders'
        )

        failure(scenario_order, reason)
      end
    end

    # Raised into the error reporter when a settlement records money it could
    # not hand anything over for.
    class IssuanceError < StandardError; end
  end
end
