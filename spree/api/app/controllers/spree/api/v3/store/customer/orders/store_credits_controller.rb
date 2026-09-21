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
            # The payment PIN is passed through and never judged here: the
            # balance is spent through Spree::StoreCredits::Apply, which is
            # where the tender's verifications are consulted, so a check in
            # this layer would be the only one the next tender needs to bypass
            # (docs/plans/6.1-phone-verification-and-payment-pin.md).
            class StoreCreditsController < Store::BaseController
              prepend_before_action :require_authentication!
              before_action :find_order!

              # POST /api/v3/store/customers/me/orders/:order_id/store_credits
              def create
                # Asked before the workflow takes its lock: a refusal writes a
                # failed-attempt counter, and a counter written inside the
                # workflow's transaction is rolled back by the very refusal
                # that produced it — a lockout that never engages. The tender
                # asks the same question again where the money moves, which is
                # what makes this a pre-check rather than the guard.
                refusal = Spree.payment_verification_refusal(order: @order, proof: params[:pay_password])
                return render_verification_refusal(refusal) if refusal

                result = Spree.order_pay_with_store_credit_workflow.call(
                  order: @order, proof: params[:pay_password]
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
            end
          end
        end
      end
    end
  end
end
