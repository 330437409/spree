require 'faraday'
require 'json'

module SpreeNotifications
  module TencentSms
    # The calls this repository makes against Tencent Cloud's SMS API.
    #
    # Errors arrive in the vendor's own vocabulary and are raised with it
    # intact: "FailedOperation.PhoneNumberInBlacklist" tells an operator what
    # to fix where "delivery failed" tells them nothing. A transport failure
    # is deliberately not retried here — a second attempt may be a second
    # message on the customer's phone, and a code that arrives twice is worse
    # than one that has to be asked for again.
    class Client
      ENDPOINT = 'https://sms.tencentcloudapi.com/'
      HOST = 'sms.tencentcloudapi.com'
      VERSION = '2021-01-11'
      OPEN_TIMEOUT = 5
      READ_TIMEOUT = 10

      # @param secret_id [String]
      # @param secret_key [String]
      # @param sms_sdk_app_id [String] the account's application id
      # @param region [String]
      def initialize(secret_id:, secret_key:, sms_sdk_app_id:, region: 'ap-guangzhou')
        @sms_sdk_app_id = sms_sdk_app_id
        @region = region
        @signer = Signer.new(secret_id: secret_id, secret_key: secret_key)
      end

      # Sends one message and answers with the vendor's status for it.
      #
      # @param phone [String] E.164, e.g. `+8613800138000`
      # @param template_id [String] the approved template's id
      # @param params [Array<String>] what fills the template, in its order
      # @param sign_name [String] the 短信签名 the template was approved under
      # @return [Hash] the vendor's send status
      def send_sms(phone:, template_id:, params:, sign_name:)
        response = request(action: 'SendSms', payload: {
                             PhoneNumberSet: [phone],
                             SmsSdkAppId: @sms_sdk_app_id,
                             SignName: sign_name,
                             TemplateId: template_id,
                             TemplateParamSet: params
                           })

        status = Array(response['SendStatusSet']).first || {}
        return status if status['Code'] == 'Ok'

        raise DeliveryError.new(status['Message'] || 'the message was refused by Tencent Cloud', code: status['Code'])
      end

      # The signatures this account has had approved, for verifying a
      # connection before it is switched on.
      #
      # @return [Array<String>]
      def sign_names
        response = request(action: 'DescribeSmsSignList', payload: { International: 0 })

        Array(response['DescribeSignListStatusSet']).filter_map { |sign| sign['SignName'] }
      end

      private

      # @return [Hash] the response envelope without its error, or a raised
      #   {SpreeNotifications::DeliveryError}
      def request(action:, payload:)
        body = @signer.body_for(payload)
        response = connection.post do |request|
          request.body = body
          @signer.headers(action: action, body: body).each { |name, value| request.headers[name] = value }
        end

        envelope = JSON.parse(response.body).fetch('Response', {})

        if (error = envelope['Error'])
          raise DeliveryError.new(error['Message'] || 'the request was refused', code: error['Code'])
        end

        envelope
      end

      def connection
        @connection ||= Faraday.new(url: ENDPOINT) do |faraday|
          faraday.headers['X-TC-Version'] = VERSION
          faraday.headers['X-TC-Region'] = @region
          faraday.options.open_timeout = OPEN_TIMEOUT
          faraday.options.timeout = READ_TIMEOUT
        end
      end
    end
  end
end
