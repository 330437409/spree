module Spree
  module Payments
    # Processes a normalized gateway webhook.
    #
    # In the workflow tier because it is the gateway's asynchronous entry
    # point into checkout: a duplicate delivery must not create a second
    # payment or complete an order twice, and integrations need somewhere to
    # observe a settled session without monkey-patching the service.
    class HandleWebhook < Spree::Workflow
      hooks :after_handle

      # The payment created or found for the session — nil for terminal
      # actions (failed, canceled) and for replayed deliveries.
      attr_reader :payment

      # @param payment_method [Spree::PaymentMethod] the method that received the webhook
      # @param action [Symbol] normalized action (:captured, :authorized, :failed, :canceled, :refund)
      # @param payment_session [Spree::PaymentSession, nil] nil is a no-op —
      #   webhooks arrive for sessions this store does not own
      # @param refund [Spree::Refund, nil] the refund a refund action concerns
      # @param refund_status [String, nil] the canonical status a refund action reports
      # @param transaction_id [String, nil] the gateway's refund reference
      # @param metadata [Hash] gateway-specific payload (charge data, psp reference)
      def perform(payment_method:, action:, payment_session: nil, refund: nil, refund_status: nil, transaction_id: nil, metadata: {})
        super

        if action == :refund
          halt!(nil) if refund.nil?
          step :apply_refund_status
          run_hooks :after_handle
          success(refund)
          return
        end

        halt!(nil) if payment_session.nil?

        case action
        when :captured, :authorized then step :settle_session
        when :failed then step :fail_session
        when :canceled then step :cancel_session
        else failure(payment_session, "Unknown webhook action: #{action}")
        end

        run_hooks :after_handle
        success(payment_session)
      end

      private

      def order
        @order ||= payment_session.owner
      end

      # Locked because a gateway may deliver the same event more than once,
      # and the redelivery races the checkout request that created the
      # session.
      def settle_session
        # Provider round trips happen here, before the lock — settlement
        # inside it must be pure database work.
        payment_session.prepare_for_settlement!

        order.with_lock do
          # Idempotency keys off the payment, not the session: an authorized
          # session is already completed (manual capture, delayed-notification
          # banks), and the capture webhook that follows must still be able to
          # complete its payment. Not halt! — that is forbidden inside a
          # transaction (there is nothing committed to halt with).
          next if payment_session.reload.payment&.completed?

          step :ensure_payment
          step :complete_session
          step :complete_owner unless order.reload.completed?
        end
      rescue Spree::Workflow::FailureSignal
        raise
      rescue StandardError => error
        Rails.error.report(
          error,
          context: { payment_session_id: payment_session.id, order_id: order.id },
          source: 'spree.payments.webhook'
        )
        failure(payment_session, error.message)
      end

      # :captured means the gateway reports the funds as moved, so the payment
      # completes with a capture event; :authorized pends it (auth-only,
      # payment_state=balance_due) until an explicit capture. The webhook's
      # action decides, not the method's capture timing.
      def ensure_payment
        @payment = payment_session.settle_payment!(captured: action == :captured, metadata: metadata)
      end

      def complete_session
        payment_session.complete if payment_session.can_complete?
      end

      def complete_owner
        completable = order.is_a?(Spree::Order) ? (order.cart || order) : order
        Spree.carts_complete_workflow.call(cart: completable)
      end

      def fail_session
        payment_session.fail if payment_session.can_fail?
      end

      def cancel_session
        payment_session.cancel if payment_session.can_cancel?
      end

      # The refund action is a state transition, not a settlement, so it is
      # idempotent by construction — the refund compares what it is with what the
      # gateway reports and moves only on a legal move.
      def apply_refund_status
        refund.apply_status!(refund_status, transaction_id: transaction_id, provider_metadata: metadata)
      end
    end
  end
end
