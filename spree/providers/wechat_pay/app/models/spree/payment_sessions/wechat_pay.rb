module Spree
  class PaymentSessions::WechatPay < PaymentSession
    # Nothing is overridden for settlement, deliberately:
    #
    # - `payment_source_for_settlement` returns nil, because WeChat issues no
    #   reusable instrument for one-off payments — the payment stands on its own.
    # - `prepare_for_settlement!` has nothing to warm, because everything
    #   settlement reads arrived in the notification this session was settled
    #   from; there is no second call to the provider to make outside the lock.
    #
    # WeChat's own numbers are recorded through `apply_settlement_metadata`,
    # which the base class merges from the metadata the gateway returned.

    # Our merchant order number for WeChat.
    #
    # @return [String]
    def merchant_order_number
      external_id
    end

    # @return [String, nil] `native`, `jsapi`, ...
    def scene
      external_data&.dig('scene')
    end

    # The QR link a Native customer scans. Not a fixed value — render it as a
    # QR code rather than storing or comparing it.
    #
    # @return [String, nil]
    def code_url
      external_data&.dig('code_url')
    end

    # WeChat's own identifier for the transaction, known only once it is paid.
    #
    # @return [String, nil]
    def transaction_id
      external_data&.dig('transaction_id')
    end

    # @return [String, nil]
    def openid
      external_data&.dig('openid')
    end

    # When the launch token lapses — two hours for `code_url` and `prepay_id`,
    # five minutes for H5's URL.
    #
    # This is not the session's own expiry, which follows the transaction's
    # payability. A lapsed token is renewed, not fatal.
    #
    # Deliberately not memoized: renewal rewrites this attribute on the same
    # instance, and a cached value would keep reporting the old token as lapsed
    # — sending the storefront into a renewal loop.
    #
    # @return [Time, nil]
    def payload_expires_at
      raw = external_data&.dig('payload_expires_at')
      raw.present? ? Time.iso8601(raw) : nil
    rescue ArgumentError
      # Written by us, so an unparseable value means the record was edited
      # outside the app. Treating it as absent is safer than raising on every
      # read of an old session.
      nil
    end

    # @return [Boolean]
    def payload_expired?
      payload_expires_at.present? && payload_expires_at <= Time.current
    end

    # Keeps WeChat's own identifiers on the session once they are known. They
    # only exist after payment, so a session created a moment ago has neither.
    #
    # Called from the synchronous confirmation path, where a query has just
    # answered; the notification path records the same values on the payment
    # instead, through the metadata the gateway returns.
    #
    # @param response [Hash] a query or notification payload
    # @return [void]
    def record_wechat_response(response)
      recorded = {
        'transaction_id' => response['transaction_id'],
        'openid' => response.dig('payer', 'openid')
      }.compact_blank

      return if recorded.empty?

      update!(external_data: (external_data || {}).merge(recorded))
    end
  end
end
