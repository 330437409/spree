module SpreeWechatPay
  # Verifies WeChat's signature over a response body or a notification.
  #
  # The string WeChat signs is three lines — timestamp, nonce, raw body — each
  # terminated by a newline including the last. The body must be the bytes as
  # received: any framework that parses and re-serialises it before this point
  # changes what was signed, which is why callers pass `request.raw_post`.
  class Verifier
    # Raised for anything that fails verification. Core turns a
    # `Spree::PaymentMethod::WebhookSignatureError` into a 401, so callers
    # translate rather than letting this escape.
    class InvalidSignature < StandardError; end

    # @param keys [Hash{String => OpenSSL::PKey::RSA, OpenSSL::PKey::PKey}] public
    #   keys by the serial the signature header named
    def initialize(keys)
      @keys = keys
    end

    # @param body [String] the raw body exactly as received
    # @param timestamp [String]
    # @param nonce [String]
    # @param signature [String] Base64
    # @param serial [String] the `Wechatpay-Serial` header value
    # @return [true]
    # @raise [InvalidSignature]
    def verify!(body:, timestamp:, nonce:, signature:, serial:)
      raise InvalidSignature, 'Missing verification headers' if timestamp.blank? || nonce.blank? || signature.blank?

      key = @keys[serial]
      # A serial we hold no key for is the one case worth distinguishing: during
      # a platform certificate rotation it means the refresh job has not caught
      # up, and an operator reading the log needs to know that rather than see a
      # bare "invalid signature".
      raise InvalidSignature, "No verification key for serial #{serial}" if key.blank?

      message = "#{timestamp}\n#{nonce}\n#{body}\n"

      verified = key.verify(
        OpenSSL::Digest.new('SHA256'),
        Base64.strict_decode64(signature),
        message
      )
      raise InvalidSignature, 'Signature does not match' unless verified

      true
    rescue ArgumentError
      # Base64 that does not decode is a malformed request, not a server error.
      raise InvalidSignature, 'Malformed signature encoding'
    end
  end
end
