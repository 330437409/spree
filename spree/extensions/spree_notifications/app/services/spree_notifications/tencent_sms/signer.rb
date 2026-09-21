require 'digest'
require 'json'
require 'openssl'

module SpreeNotifications
  module TencentSms
    # TC3-HMAC-SHA256, the signature Tencent Cloud takes on every API 3.0
    # request.
    #
    # Kept as its own object because it is the one part of a send that can be
    # checked without an account: the canonical request and its hash are
    # published in Tencent's own worked example, and a signature that is wrong
    # by a byte is refused with "AuthFailure.SignatureFailure" and nothing
    # else useful.
    class Signer
      ALGORITHM = 'TC3-HMAC-SHA256'
      SERVICE = 'sms'
      HOST = 'sms.tencentcloudapi.com'
      CONTENT_TYPE = 'application/json; charset=utf-8'
      SIGNED_HEADERS = 'content-type;host;x-tc-action'

      # @param secret_id [String]
      # @param secret_key [String]
      def initialize(secret_id:, secret_key:)
        @secret_id = secret_id
        @secret_key = secret_key
      end

      # Every header the request needs, Authorization included. The action
      # appears in the header in its documented casing and in the signature in
      # lowercase — that is Tencent's rule, not an oversight.
      #
      # @param action [String] e.g. `SendSms`
      # @param body [String] the exact JSON that will be sent: what is signed
      #   has to be what travels
      # @param timestamp [Integer] seconds; the date is derived from it in UTC
      # @return [Hash]
      def headers(action:, body:, timestamp: Time.now.to_i)
        date = Time.at(timestamp).utc.strftime('%Y-%m-%d')

        {
          'Content-Type' => CONTENT_TYPE,
          'Host' => HOST,
          'X-TC-Action' => action,
          'X-TC-Timestamp' => timestamp.to_s,
          'Authorization' => [
            "#{ALGORITHM} Credential=#{@secret_id}/#{date}/#{SERVICE}/tc3_request",
            "SignedHeaders=#{SIGNED_HEADERS}",
            "Signature=#{signature(string_to_sign: string_to_sign(canonical_request: canonical_request(action: action, body: body), date: date, timestamp: timestamp), date: date)}"
          ].join(', ')
        }
      end

      # The request as the signature sees it: method, path, query, the signed
      # headers, and the body's hash. Public so a spec can hold it against
      # Tencent's published example.
      #
      # @return [String]
      def canonical_request(action:, body:, content_type: CONTENT_TYPE, host: HOST)
        [
          'POST',
          '/',
          '',
          "content-type:#{content_type}\nhost:#{host}\nx-tc-action:#{action.downcase}\n",
          SIGNED_HEADERS,
          Digest::SHA256.hexdigest(body)
        ].join("\n")
      end

      # @return [String]
      def string_to_sign(canonical_request:, date:, timestamp:, service: SERVICE)
        [
          ALGORITHM,
          timestamp.to_s,
          "#{date}/#{service}/tc3_request",
          Digest::SHA256.hexdigest(canonical_request)
        ].join("\n")
      end

      # @return [String] lowercase hex
      def signature(string_to_sign:, date:, service: SERVICE)
        secret_date = OpenSSL::HMAC.digest('sha256', "TC3#{@secret_key}", date)
        secret_service = OpenSSL::HMAC.digest('sha256', secret_date, service)
        secret_signing = OpenSSL::HMAC.digest('sha256', secret_service, 'tc3_request')

        OpenSSL::HMAC.hexdigest('sha256', secret_signing, string_to_sign)
      end

      # @return [String] the JSON body to send, signed exactly as generated
      def body_for(payload)
        JSON.generate(payload)
      end
    end
  end
end
