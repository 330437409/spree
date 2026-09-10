module SpreeWechatPay
  # Everything that varies between one merchant arrangement and another, in one
  # object.
  #
  # A direct merchant has one merchant number and one application identifier per
  # scene. 服务商 (partner) mode adds a service provider above and a sub-merchant
  # below, changes which openid flavour is valid, and moves ordering onto a
  # different path — which is why this is a resolved context rather than a
  # couple of lookup tables threaded through every payload builder.
  #
  # Only `direct` is implemented. The mode is a declared preference from the
  # start so that lifting the restriction is the whole of the future work,
  # instead of a `partner_mode?` predicate appearing in five scene
  # implementations later.
  class MerchantContext
    include ActiveModel::Model
    include ActiveModel::Attributes

    MODES = %w[direct].freeze

    # How WeChat's own signature is verified. WeChat steers new integrations to
    # the public key, which never expires; established merchants are on platform
    # certificates, which rotate every five years. Both are supported because
    # supporting one would exclude half the merchant base.
    VERIFICATION_MODES = %w[public_key platform_certificate].freeze

    # The transaction endpoint per scene, from the plan's API contract matrix.
    # JSAPI and the mini program share one endpoint, and only the launch step and
    # the application identifier differ.
    TRANSACTION_PATHS = {
      'jsapi' => '/v3/pay/transactions/jsapi',
      'mini_program' => '/v3/pay/transactions/jsapi',
      'native' => '/v3/pay/transactions/native',
      'h5' => '/v3/pay/transactions/h5',
      'app' => '/v3/pay/transactions/app'
    }.freeze

    attribute :mode, :string, default: 'direct'
    attribute :merchant_id, :string
    attribute :certificate_serial, :string
    attribute :api_v3_key, :string
    attribute :private_key_pem, :string
    attribute :verification_mode, :string, default: 'public_key'
    attribute :public_key_pem, :string
    attribute :public_key_id, :string
    attribute :jsapi_app_id, :string
    # The official account's own secret. Only ever used server-side, to exchange
    # an authorization code for the payer's openid — it is the one credential a
    # storefront must never hold.
    attribute :jsapi_app_secret, :string
    attribute :mini_program_app_id, :string
    attribute :mini_program_app_secret, :string
    attribute :app_app_id, :string
    # Native and H5 have no application identity of their own, but WeChat still
    # requires an `appid` on the request — any of the three kinds, as long as it
    # is bound to the merchant number. This is that identifier.
    attribute :bound_app_id, :string

    validates :mode, inclusion: { in: MODES }
    validates :verification_mode, inclusion: { in: VERIFICATION_MODES }
    validates :merchant_id, :certificate_serial, :api_v3_key, :private_key_pem, presence: true

    # The mode is explicit rather than inferred from which key is filled in:
    # inferring would make "both filled" and "neither filled" unrepresentable in
    # the message an operator needs to read.
    with_options if: -> { verification_mode == 'public_key' } do
      validates :public_key_pem, :public_key_id, presence: true
    end

    # Required only for the scene that needs it: a store taking QR payments has
    # no reason to hold an official account's secret.
    with_options if: -> { jsapi_app_id.present? } do
      validates :jsapi_app_secret, presence: true
    end

    with_options if: -> { mini_program_app_id.present? } do
      validates :mini_program_app_secret, presence: true
    end

    # An application identifier is required per scene, not once: an official
    # account, a mini program and a mobile app are three different identities
    # issued by two different platforms, and WeChat requires the identifier used
    # to launch payment to equal the one used to place the order.
    #
    # Native and H5 are the exception that proves the rule — they carry no payer
    # identity, so WeChat accepts any bound identifier, which is `bound_app_id`.
    #
    # @param scene [String, Symbol]
    # @return [String, nil]
    def app_id_for(scene)
      case scene.to_s
      when 'jsapi' then jsapi_app_id
      when 'mini_program' then mini_program_app_id
      when 'app' then app_app_id
      when 'native', 'h5' then bound_app_id
      end
    end

    # @param scene [String, Symbol]
    # @return [String]
    def transaction_path(scene)
      path = TRANSACTION_PATHS[scene.to_s]
      raise ArgumentError, "Unknown WeChat Pay scene: #{scene}" if path.blank?

      # Partner mode orders under `/v3/pay/partner/...`. Its refunds, in
      # contrast, keep the ordinary path and differ only by a sub-merchant
      # field — so refunds must not follow this method blindly.
      path
    end

    # @return [OpenSSL::PKey::RSA]
    def private_key
      @private_key ||= OpenSSL::PKey::RSA.new(private_key_pem)
    end

    # @return [SpreeWechatPay::Signer]
    def signer
      @signer ||= Signer.new(
        private_key: private_key,
        merchant_id: merchant_id,
        certificate_serial: certificate_serial
      )
    end
  end
end
