module Spree
  module Api
    module V3
      module Store
        # Why an order was called off, in the merchant's own words: the list a
        # customer picks from when they cancel one. Only the reasons still in
        # use are offered — a retired one stays on the orders that already
        # carry it, which is what reporting needs, without being handed to
        # another customer.
        class OrderCancellationReasonsController < Store::BaseController
          # GET /api/v3/store/order_cancellation_reasons
          def index
            render json: {
              data: reasons.map { |reason| serializer_class.new(reason, params: serializer_params).to_h }
            }
          end

          private

          # `NamedType` already lists them alphabetically, so `active` is the
          # only narrowing this read needs.
          def reasons
            current_store.order_cancellation_reasons.active
          end

          def serializer_class
            Spree::Api::V3::Store::OrderCancellationReasonSerializer
          end
        end
      end
    end
  end
end
