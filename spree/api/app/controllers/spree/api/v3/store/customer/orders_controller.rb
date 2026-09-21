module Spree
  module Api
    module V3
      module Store
        module Customer
          class OrdersController < ResourceController
            prepend_before_action :require_authentication!

            # DELETE /api/v3/store/customers/me/orders/:id
            #
            # Takes the order off the customer's own list. Nothing is destroyed
            # — the row stays for the merchant, with fulfillment, refunds and
            # reporting untouched — which is what the customer is asking for:
            # gone from *their* history
            # (docs/plans/6.1-store-api-miniprogram-gaps.md).
            def destroy
              @resource.hide_from_customer!
              head :no_content
            end

            protected

            def model_class
              Spree::Order
            end

            def serializer_class
              Spree.api.order_serializer
            end

            def set_parent
              @parent = current_user
            end

            def parent_association
              :orders
            end

            # Every action here is the customer's own side of their orders, so
            # hiding one removes it from the list and from a lookup by id alike.
            # The merchant reaches the order through the Admin API, where
            # nothing is hidden.
            def scope
              super.for_store(current_store).complete.visible_to_customer
            end

            # The withdrawal deadline reads both on every row, so without
            # these an order history pays two queries per order.
            def collection_includes
              super + [:market, :fulfillments]
            end
          end
        end
      end
    end
  end
end
