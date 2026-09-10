module Spree
  module Payments
    class HandleWebhookJob < Spree::BaseJob
      queue_as Spree.queues.payment_webhooks

      retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
      retry_on ActiveRecord::LockWaitTimeout, wait: 5.seconds, attempts: 3
      discard_on ActiveRecord::RecordNotFound

      # `metadata` is whatever the gateway's `parse_webhook_event` returned —
      # the provider's own identifiers for what just happened. It reaches the
      # workflow so the session can record them on the payment.
      def perform(payment_method_id:, action:, payment_session_id:, metadata: {})
        payment_method = Spree::PaymentMethod.find(payment_method_id)
        payment_session = Spree::PaymentSession.find(payment_session_id)

        Spree.payments_handle_webhook_workflow.call(
          payment_method: payment_method,
          action: action.to_sym,
          payment_session: payment_session,
          metadata: metadata || {}
        )
      end
    end
  end
end
