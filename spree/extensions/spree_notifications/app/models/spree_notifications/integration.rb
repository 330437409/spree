module SpreeNotifications
  # A store's SMS account at Tencent Cloud — the credential home the SMS
  # channel sends through, and the only place in this repository that holds an
  # SMS secret.
  #
  # The templates are part of the account rather than of the code: a Chinese
  # SMS provider sends an approved template with numbered parameters, so an
  # event resolves to a template id here and the parameters come from the
  # event's own vocabulary. A missing entry is refused loudly — sending
  # without one would reach the customer as a message with empty placeholders,
  # and a verification code that arrives blank is worse than one that does not
  # arrive (docs/plans/6.1-notifications.md).
  class Integration < Spree::Integration
    # The two credentials an operator must supply, declared first because the
    # form renders in this order.
    preference :secret_id, :password
    preference :secret_key, :password
    # The account's application id (`SmsSdkAppId`), which is what Tencent
    # bills and rate-limits against.
    preference :sms_sdk_app_id, :string
    # The 短信签名 every message is sent under. It is approved per account
    # and must match the template's own signature.
    preference :sign_name, :string
    preference :region, :string, default: 'ap-guangzhou'
    # event key => the id of the template approved for it, e.g.
    # `{ 'verification_code' => '1234567' }`.
    preference :templates, :hash, default: {}

    def self.integration_group
      'notifications'
    end

    def self.integration_name
      'Tencent Cloud SMS'
    end

    def self.description
      'Verification codes and account messages by text, through your Tencent Cloud SMS account.'
    end

    # Verifies the account by listing the signatures it has had approved, and
    # checks that the configured one is among them: credentials that
    # authenticate but a 签名 that does not exist are an account that cannot
    # send, and the merchant should learn that here rather than from a customer
    # who never received a code.
    #
    # Rescues broadly — a DNS failure or a timeout must surface as a clean
    # activation error, never a 500.
    def can_connect?
      if preferred_secret_id.blank? || preferred_secret_key.blank? || preferred_sms_sdk_app_id.blank?
        self.connection_error_message = Spree.t('notifications.errors.credentials_missing')
        return false
      end

      approved = client.sign_names

      if preferred_sign_name.present? && approved.exclude?(preferred_sign_name)
        self.connection_error_message =
          Spree.t('notifications.errors.sign_name_not_approved', sign_name: preferred_sign_name)
        return false
      end

      true
    rescue StandardError => error
      self.connection_error_message = error.message
      false
    end

    # Sends one message through this account.
    #
    # @param phone [String] digits without the country code, as the channel
    #   normalizes them
    # @param event [String] the event whose template is used
    # @param payload [Hash] what the template's parameters are read from
    # @return [Hash] the vendor's send status
    def deliver_sms(phone:, event:, payload:)
      template_id = template_id_for(event)

      client.send_sms(
        phone: "+86#{phone}",
        template_id: template_id,
        params: Spree::Notifications.params_for(event, payload),
        sign_name: preferred_sign_name
      )
    end

    # @return [SpreeNotifications::TencentSms::Client]
    def client
      @client ||= SpreeNotifications::TencentSms::Client.new(
        secret_id: preferred_secret_id,
        secret_key: preferred_secret_key,
        sms_sdk_app_id: preferred_sms_sdk_app_id,
        region: preferred_region
      )
    end

    private

    # A template is per event and approved in advance, so its absence is a
    # configuration error rather than a per-message one — and it is raised
    # rather than reported, because the caller is mid-send.
    #
    # @return [String]
    def template_id_for(event)
      template_id = preferred_templates[event.to_s]

      if template_id.blank?
        raise SpreeNotifications::UndeliverableError,
              Spree.t('notifications.errors.template_missing', event: event)
      end

      template_id.to_s
    end
  end
end
