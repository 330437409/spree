module Spree
  module Api
    module V3
      module Store
        module Customer
          module Orders
            # A customer calling off their own order.
            #
            # It is creating a cancellation rather than performing a `cancel`
            # action: one act, happening once, whose result is the order in its
            # canceled state — which is what comes back
            # (docs/plans/6.1-store-api-miniprogram-gaps.md).
            #
            # Only the customer's own orders are reachable, because the lookup
            # runs through their own association: somebody else's order is a
            # 404 rather than a refusal that confirms it exists. Whether this
            # order can still be called off is the workflow's call, not this
            # controller's — a parcel already on its way cannot be.
            class CancellationsController < Store::BaseController
              prepend_before_action :require_authentication!
              before_action :find_order!

              # POST /api/v3/store/customers/me/orders/:order_id/cancellation
              #
              # No canceler is passed: the actor columns record the staff or
              # system identity that acted, and this codebase's actor registry
              # holds admins and API keys, not customers
              # (docs/plans/fork-decisions.md, 2026-09-21, the customer's
              # cancellation). The order still carries when it was called off,
              # the reason and the customer's own note.
              def create
                result = Spree.order_cancel_workflow.call(
                  order: @order,
                  reason: reason,
                  note: permitted_params[:note]
                )

                if result.success?
                  render json: Spree.api.order_serializer.new(@order, params: serializer_params).to_h
                else
                  render_result_error(result)
                end
              end

              private

              def find_order!
                @order = current_user.orders.for_store(current_store).find_by_prefix_id!(params[:order_id])
              end

              # The merchant's own vocabulary, read through the store's list so
              # a reason from another store is not one at all — the workflow
              # holds the same line, and this keeps the refusal out of its way.
              #
              # @return [Spree::OrderCancellationReason, nil]
              def reason
                id = permitted_params[:reason_id]
                return nil if id.blank?

                current_store.order_cancellation_reasons.find_by_prefix_id(id)
              end

              def permitted_params
                params.permit(:reason_id, :note)
              end
            end
          end
        end
      end
    end
  end
end
