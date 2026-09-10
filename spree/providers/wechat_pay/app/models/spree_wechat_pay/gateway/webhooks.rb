module SpreeWechatPay
  class Gateway < ::Spree::Gateway
    # Verifying and reading WeChat's notifications.
    #
    # WeChat has no endpoint registration and no per-endpoint signing secret:
    # every transaction carries the `notify_url` it wants notified at, and the
    # signature is verified against the merchant's public key or a platform
    # certificate. So there is nothing to register and nothing to store beyond
    # the credentials themselves.
    module Webhooks
      extend ActiveSupport::Concern

      # WeChat's payment notifications are only ever sent for a payment that
      # succeeded; failures and closures are discovered by querying. Subscribing
      # to more would mean handling events that never arrive.
      PAYMENT_EVENT_ACTIONS = {
        'TRANSACTION.SUCCESS' => :captured
      }.freeze

      # A refund notification arrives when a refund reaches a terminal or
      # non-terminal state worth knowing about.
      REFUND_EVENT_TYPES = %w[REFUND.SUCCESS REFUND.ABNORMAL REFUND.CLOSED].freeze

      # Translates a WeChat notification into the shape core consumes.
      # Everything after this — idempotency, locking, payment creation, order
      # completion — belongs to core.
      #
      # @param raw_body [String] the exact bytes received
      # @param headers [Hash] the request headers
      # @return [Hash, nil] nil for an event this gateway does not act on
      # @raise [Spree::PaymentMethod::WebhookSignatureError]
      def parse_webhook_event(raw_body, headers)
        verify_webhook_signature(raw_body, headers)

        envelope = parse_envelope(raw_body)
        return nil if envelope.nil?

        notification = Notification.new(envelope: envelope, api_v3_key: merchant_context.api_v3_key)
        return nil unless notification.readable?

        if REFUND_EVENT_TYPES.include?(notification.event_type)
          parse_refund_event(notification)
        else
          parse_payment_event(notification)
        end
      end

      private

      def parse_payment_event(notification)
        action = PAYMENT_EVENT_ACTIONS[notification.event_type]
        return nil unless action

        resource = notification.resource
        payment_session = Spree::PaymentSessions::WechatPay.find_by(
          payment_method: self,
          external_id: resource['out_trade_no']
        )
        # A notification for a transaction this store does not own is
        # acknowledged without being acted on, which is what a callback URL
        # shared by several stores depends on.
        return nil if payment_session.nil?

        {
          action: action,
          payment_session: payment_session,
          # WeChat's own identifiers for what just happened. Core passes these
          # to the session, which records them on the payment.
          metadata: payment_metadata(resource)
        }
      end

      # A refund notification carries a refund, found by the lookup chain rather
      # than by the session's external id, and a canonical target status core
      # applies idempotently.
      def parse_refund_event(notification)
        resource = notification.resource
        refund = find_refund(resource)

        return report_unknown_refund(resource) if refund.nil?

        {
          action: :refund,
          refund: refund,
          refund_status: Refund::STATUS_ACTIONS[resource['refund_status']] || 'processing',
          transaction_id: resource['refund_id'],
          metadata: refund_metadata(resource)
        }
      end

      # The chain, in order: WeChat's refund id against the refund's own
      # transaction_id, then our refund number against the metadata it was
      # written to before the API call. These are the only two identities that
      # settle a refund — a match by `out_trade_no` plus amount is deliberately
      # not here: it is orphan evidence, never an auto-attachment (see the
      # constraint in the plan).
      def find_refund(resource)
        refund = refunds.find_by(transaction_id: resource['refund_id'])
        return refund if refund

        out_refund_no = resource['out_refund_no']
        return nil if out_refund_no.blank?

        refunds.processing.find_each do |candidate|
          return candidate if candidate.metadata['wechat_pay_out_refund_no'] == out_refund_no
        end

        nil
      end

      # A refund notification this installation has no record for is a reportable
      # event, not a crash and not a silent success — the callback answers 200 so
      # WeChat stops retrying, and the operator is told what was missed.
      def report_unknown_refund(resource)
        Rails.error.report(
          "WeChat Pay refund notification for an unknown refund: #{resource['refund_id']}",
          handled: true,
          context: { out_refund_no: resource['out_refund_no'], out_trade_no: resource['out_trade_no'] },
          source: 'spree_wechat_pay'
        )
        nil
      end

      # This payment method's own refunds, so a notification cannot act on a
      # refund belonging to another store's merchant account.
      def refunds
        Spree::Refund.joins(:payment).merge(Spree::Payment.where(payment_method_id: id))
      end

      # WeChat's own identifiers for a refund, under the gateway's own names.
      def refund_metadata(resource)
        {
          'wechat_pay_refund_id' => resource['refund_id'],
          'wechat_pay_refund_status' => resource['refund_status'],
          'wechat_pay_out_refund_no' => resource['out_refund_no'],
          'wechat_pay_last_event_at' => Time.current.iso8601
        }.compact_blank
      end

      def verify_webhook_signature(raw_body, headers)
        verifier.verify!(
          body: raw_body,
          timestamp: header(headers, 'Wechatpay-Timestamp').to_s,
          nonce: header(headers, 'Wechatpay-Nonce').to_s,
          signature: header(headers, 'Wechatpay-Signature').to_s,
          serial: header(headers, 'Wechatpay-Serial').to_s
        )
      rescue Verifier::InvalidSignature => error
        raise Spree::PaymentMethod::WebhookSignatureError, error.message
      end

      # Headers arrive as Rack's `HTTP_` form from a request and as plain names
      # from anything else, so both are accepted rather than making every caller
      # remember which it is holding.
      def header(headers, name)
        rack_name = "HTTP_#{name.upcase.tr('-', '_')}"

        headers[rack_name].presence || headers[name].presence
      end

      def parse_envelope(raw_body)
        JSON.parse(raw_body)
      rescue JSON::ParserError
        # Unauthenticated garbage is a rejected webhook, not a server error to
        # retry — and the signature was already checked, so this is a body that
        # verified but is not the JSON it claims to be.
        raise Spree::PaymentMethod::WebhookSignatureError, 'Malformed webhook payload'
      end
    end
  end
end
