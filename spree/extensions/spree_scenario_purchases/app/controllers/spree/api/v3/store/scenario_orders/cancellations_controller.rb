module Spree
  module Api
    module V3
      module Store
        module ScenarioOrders
          # Calling off a purchase that was not paid for: creating a
          # cancellation, not cancelling through an action — the same shape an
          # order's own cancellation has.
          class CancellationsController < ResourceController
            prepend_before_action :require_authentication!
            before_action :set_scenario_order

            def create
              result = Spree::ScenarioOrders::Cancel.call(scenario_order: @scenario_order)

              return render_result_error(result) unless result.success?

              render json: serialize_resource(result.value)
            end

            protected

            def model_class
              Spree::ScenarioOrder
            end

            def serializer_class
              Spree::Api::V3::Store::ScenarioOrderSerializer
            end

            private

            def set_scenario_order
              @scenario_order = Spree::ScenarioOrder.for_customer(current_user).
                                find_by_prefix_id!(params[:scenario_order_id])
            end
          end
        end
      end
    end
  end
end
