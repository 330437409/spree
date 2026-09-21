module Spree
  module Api
    module V3
      module Store
        module Customer
          module Orders
            # Paying what an order still owes from the customer's own stored
            # value — the balance payment an unpaid order offers. It answers
            # with the order, because that is the only thing the write can be
            # read in terms of: what was owed is paid, or the order is
            # unchanged.
            #
            # Only the customer's own orders are reachable, because the lookup
            # runs through their own association: somebody else's order is a
            # 404 rather than a refusal that confirms it exists. What a balance
            # can pay, and what happens when it cannot cover the order, is the
            # workflow's call (docs/plans/6.1-store-api-miniprogram-gaps.md).
            #
            # No payment PIN is read here on purpose: the balance is spent
            # through Spree::StoreCredits::Apply, which is where the PIN is
            # consulted, so a second check in this layer would be the only one
            # the next tender needs to bypass
            # (docs/plans/6.1-phone-verification-and-payment-pin.md).
            class StoreCreditsController < Store::BaseController
              prepend_before_action :require_authentication!
              before_action :find_order!

              # POST /api/v3/store/customers/me/orders/:order_id/store_credits
              def create
                result = Spree.order_pay_with_store_credit_workflow.call(order: @order)

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
            end
          end
        end
      end
    end
  end
end
