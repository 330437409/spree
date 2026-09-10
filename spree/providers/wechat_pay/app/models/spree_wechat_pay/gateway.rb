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

    # Off until refunds are implemented. WeChat does settle a refund after
    # accepting it, so this will become true — but claiming the capability now is
    # worse than not having it: `Refunds::Create` would start the refund in
    # `processing`, the credit call would fail because no `credit` verb exists
    # yet, and the row would be kept (that being what opt-in means), leaving a
    # refund that reserves the payment's balance forever and never resolves.
    def async_refunds?
      false
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
      Client.new(context: merchant_context)
    end

    # @return [SpreeWechatPay::CertificateStore]
    def certificate_store
      CertificateStore.new(context: merchant_context, client: client)
    end

    # The keys WeChat's signatures are verified against, by the serial its
    # signature header names. Reads the cache only — never called on a path that
    # owes WeChat a fast answer.
    #
    # @return [SpreeWechatPay::Verifier]
    def verifier
      Verifier.new(certificate_store.verification_keys)
    end

    private

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
