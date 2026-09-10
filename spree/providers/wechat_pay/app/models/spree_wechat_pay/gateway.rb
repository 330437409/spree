module SpreeWechatPay
  # WeChat Pay gateway, built on core's payment session API.
  #
  # Credentials live in this record's preferences rather than in a
  # `Spree::Integration`, because payments have one credential set per merchant
  # entity and several per store — exactly what payment method rows model
  # (decisions.md, 2026-07-30). An integration's store+type uniqueness would
  # fight that, and a second merchant account is a second record here.
  class Gateway < ::Spree::Gateway
    include SpreeWechatPay::Gateway::PaymentSessions
    include SpreeWechatPay::Gateway::Webhooks

    preference :merchant_mode, :string, default: 'direct'
    preference :merchant_id, :string
    preference :merchant_private_key, :password
    preference :merchant_certificate_serial, :string
    preference :api_v3_key, :password
    preference :verification_mode, :string, default: 'public_key'
    preference :wechat_pay_public_key, :password
    preference :wechat_pay_public_key_id, :string
    preference :jsapi_app_id, :string
    preference :jsapi_app_secret, :password
    preference :mini_program_app_id, :string
    preference :mini_program_app_secret, :password
    preference :app_app_id, :string
    # Native and H5 carry no payer identity, but WeChat still requires an
    # `appid` on the request — any of the three kinds, as long as it is bound to
    # the merchant number.
    preference :bound_app_id, :string
    preference :enabled_scenes, :array, default: []
    preference :statement_descriptor, :string

    validate :validate_credentials, unless: -> { Rails.env.test? }, if: :credentials_present?
    validate :validate_capture_method

    def provider_class
      self.class
    end

    def default_name
      'WeChat Pay'
    end

    def method_type
      'spree_wechat_pay'
    end

    def payment_icon_name
      'wechat_pay'
    end

    # WeChat issues no reusable instrument for one-off payments, so a payment
    # carries no Spree-side source. Entrusted deduction (委托代扣) is a separate
    # contracting product with its own onboarding, and is not this.
    def source_required?
      false
    end

    def payment_source_class
      nil
    end

    def payment_profiles_supported?
      false
    end

    def setup_session_supported?
      false
    end

    def session_required?
      true
    end

    # WeChat accepts a refund and settles it later, so a refund starts in
    # `processing` and is resolved by notification or reconciliation.
    def async_refunds?
      true
    end

    # WeChat Pay's domestic API settles in yuan alone, so an order in any other
    # currency cannot be paid this way. Without this the payload's hardcoded
    # `CNY` would be attached to another currency's minor units — the same
    # number, a different amount of money.
    #
    # @param order [Spree::Order]
    # @return [Boolean]
    def available_for_order?(order)
      super && order.currency.to_s == 'CNY'
    end

    # @return [SpreeWechatPay::MerchantContext]
    def merchant_context
      MerchantContext.new(
        mode: preferred_merchant_mode,
        merchant_id: preferred_merchant_id,
        certificate_serial: preferred_merchant_certificate_serial,
        api_v3_key: preferred_api_v3_key,
        private_key_pem: preferred_merchant_private_key,
        verification_mode: preferred_verification_mode,
        public_key_pem: preferred_wechat_pay_public_key,
        public_key_id: preferred_wechat_pay_public_key_id,
        jsapi_app_id: preferred_jsapi_app_id,
        jsapi_app_secret: preferred_jsapi_app_secret,
        mini_program_app_id: preferred_mini_program_app_id,
        mini_program_app_secret: preferred_mini_program_app_secret,
        app_app_id: preferred_app_app_id,
        bound_app_id: preferred_bound_app_id
      )
    end

    # Built per call rather than memoized: an operator who corrects a credential
    # expects the next payment to use it, and re-parsing a key costs nothing
    # beside the network call it precedes.
    #
    # @return [SpreeWechatPay::Client]
    def client
      Client.new(context: merchant_context, verifier: -> { verifier })
    end

    # @return [SpreeWechatPay::CertificateStore]
    def certificate_store
      CertificateStore.new(context: merchant_context, client: unverified_client)
    end

    # The keys WeChat's signatures are verified against, by the serial its
    # signature header names. Reads the cache only — never called on a path that
    # owes WeChat a fast answer.
    #
    # @return [SpreeWechatPay::Verifier]
    def verifier
      Verifier.new(certificate_store.verification_keys)
    end

    # Credits a payment back at WeChat. Core calls this from `Spree::Refund#perform!`
    # with the payment's merchant order number as `transaction_id` and the refund
    # itself as `originator`.
    #
    # WeChat's answer is acceptance, not completion, so the response reports the
    # refund's own `refund_id` as the authorization — core records it on the
    # refund's transaction_id — and the refund stays `processing` until the
    # notification or reconciliation resolves it.
    #
    # @param amount_in_cents [Integer] the amount to refund, in fen
    # @param transaction_id [String] the payment's merchant order number
    # @param originator [Spree::Refund] the refund being credited
    # @return [Spree::PaymentResponse]
    def credit(amount_in_cents, transaction_id, originator: nil)
      refund_number = MerchantOrderNumber.generate_refund(originator)
      record_refund_number(originator, refund_number)

      response = refund_for(refund_number).create(
        refund_payload(
          out_trade_no: transaction_id,
          out_refund_no: refund_number,
          amount_in_cents: amount_in_cents,
          payment: originator&.payment
        )
      )

      Spree::PaymentResponse.new(true, nil, response, authorization: response['refund_id'])
    rescue ApiError => error
      # A definite rejection — WeChat named what is wrong (balance, order state) —
      # surfaced in WeChat's own words rather than as a generic gateway failure.
      raise Spree::Core::GatewayError, error.message
    end

    # Asks WeChat what became of a refund, for reconciliation to apply.
    #
    # @param refund_number [String] our `out_refund_no`
    # @return [Hash] the refund as WeChat sees it
    def query_refund(refund_number)
      refund_for(refund_number).query
    end

    # Encrypts a sensitive field WeChat will decrypt with its own private key —
    # the configured WeChat Pay public key, or the latest platform certificate.
    #
    # @param plaintext [String]
    # @return [String] Base64 ciphertext
    def encrypt_sensitive_field(plaintext)
      SensitiveField.encrypt(plaintext, key: sensitive_field_encryption_key)
    end

    # Decrypts a sensitive field WeChat encrypted against the merchant
    # certificate's public key.
    #
    # @param ciphertext [String] Base64
    # @return [String] the plaintext
    def decrypt_sensitive_field(ciphertext)
      SensitiveField.decrypt(ciphertext, key: merchant_context.private_key)
    end

    private

    # The one client that does not verify what it is told, because it is the one
    # that fetches the very keys verification needs: a cold certificate cache
    # would otherwise ask for the keys, fetch them, and try to verify that fetch
    # against keys it does not have yet. Every official WeChat Pay SDK carves
    # out the same call for the same reason.
    #
    # The exposure is bounded — the download is the only thing this client is
    # used for, and what it returns is still decrypted with the APIv3 key, which
    # is what proves a genuine certificate set arrived.
    #
    # @return [SpreeWechatPay::Client]
    def unverified_client
      Client.new(context: merchant_context)
    end

    # @param merchant_refund_number [String]
    # @return [SpreeWechatPay::Refund]
    def refund_for(merchant_refund_number)
      Refund.new(context: merchant_context, client: client, merchant_refund_number: merchant_refund_number)
    end

    # @return [OpenSSL::PKey::RSA] the key a sensitive field is encrypted with
    def sensitive_field_encryption_key
      if merchant_context.verification_mode == 'public_key'
        OpenSSL::PKey::RSA.new(merchant_context.public_key_pem)
      else
        certificate_store.current_public_key
      end
    end

    # The refund request. `amount.total` is the original order amount (the
    # payment's captured amount), `amount.refund` is what is being given back.
    def refund_payload(out_trade_no:, out_refund_no:, amount_in_cents:, payment:)
      {
        'out_trade_no' => out_trade_no,
        'out_refund_no' => out_refund_no,
        'notify_url' => webhook_url,
        'amount' => {
          'refund' => amount_in_cents,
          'total' => total_in_cents(payment),
          'currency' => 'CNY'
        }
      }
    end

    def total_in_cents(payment)
      return 0 if payment.blank?

      Spree::Money.new(payment.amount, currency: payment.currency).cents
    end

    # The refund number is the gateway's own correlation key, written down before
    # the API call: if the acceptance response is lost to a timeout, the refund
    # is still findable by this number when the notification or reconciliation
    # arrives.
    def record_refund_number(refund, refund_number)
      return if refund.blank?

      refund.metadata['wechat_pay_out_refund_no'] = refund_number
      refund.update_columns(metadata: refund.metadata)
    end

    # WeChat's own identifiers for a transaction, under the gateway's own names.
    # Written to the payment so an operator holding a payment can find it in the
    # merchant platform, where WeChat knows it only by these.
    #
    # @param response [Hash] a query result or a notification resource
    # @return [Hash]
    def payment_metadata(response)
      {
        'wechat_pay_transaction_id' => response['transaction_id'],
        'wechat_pay_trade_state' => response['trade_state'],
        'wechat_pay_out_trade_no' => response['out_trade_no'],
        'wechat_pay_openid' => response.dig('payer', 'openid')
      }.compact_blank
    end

    # WeChat Pay's domestic API offers no general authorize-then-capture split,
    # so a capture method other than `checkout` is a configuration this gateway
    # cannot honour. Rejecting it when the method is saved is the point — a store
    # set to dispatch-capture would otherwise find out when the first dispatch
    # tried to take money that was already taken.
    #
    # Read through `resolved_capture_method`, not the raw column: an unset
    # preference inherits the store's choice, and it is the inherited value that
    # actually applies.
    def validate_capture_method
      return if store.blank?
      return if resolved_capture_method == 'checkout'

      errors.add(:capture_method, :unsupported,
                 message: Spree.t('wechat_pay.errors.capture_method_unsupported'))
    end

    def credentials_present?
      preferred_merchant_id.present? && preferred_merchant_private_key.present?
    end

    # One authenticated call proves both halves of the credential set that can
    # be proved remotely: the signature on the way out, and the APIv3 key on the
    # way back, since downloading platform certificates requires decrypting them
    # with it. What it cannot prove is that WeChat can reach *us* — that needs a
    # publicly reachable callback, so it stays an explicit action.
    def validate_credentials
      certificate_store.refresh!
    rescue ApiError => error
      errors.add(:base, :credentials_rejected,
                 message: Spree.t('wechat_pay.errors.credentials_rejected', message: error.message))
    rescue ConnectionError
      errors.add(:base, :wechat_pay_unavailable,
                 message: Spree.t('wechat_pay.errors.unavailable'))
    rescue OpenSSL::PKey::RSAError
      errors.add(:base, :invalid_private_key,
                 message: Spree.t('wechat_pay.errors.invalid_private_key'))
    end
  end
end
