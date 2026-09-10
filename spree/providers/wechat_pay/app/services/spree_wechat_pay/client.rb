module SpreeWechatPay
  # Talks to the WeChat Pay v3 API: signs every request, reads every answer.
  #
  # Everything above this class deals in WeChat's own vocabulary, and this is
  # the only place that knows about HTTP.
  class Client
    OPEN_TIMEOUT = 5
    # WeChat requires a notification to be acknowledged within five seconds, but
    # that is the inbound direction. Outbound calls get longer than a customer
    # would wait, and are never made from the webhook request itself.
    READ_TIMEOUT = 15
    # Queries are reads. Retrying one costs nothing and cannot move money, so the
    # transport does it. A create or a refund is never retried here: an
    # unanswered request may have been accepted, and only the caller knows how to
    # find out — by querying under the same merchant number before trying again.
    QUERY_RETRIES = 2

    # @param context [SpreeWechatPay::MerchantContext]
    # @param connection [Faraday::Connection, nil] injected by specs
    # @param verifier [#call, SpreeWechatPay::Verifier, nil] what every answer is
    #   checked against; a callable is resolved per answer, so a certificate
    #   rotation is picked up without rebuilding clients
    def initialize(context:, connection: nil, verifier: nil)
      @context = context
      @connection = connection || build_connection
      @verifier = verifier
    end

    # @param path [String]
    # @return [Hash]
    def get(path, retries: QUERY_RETRIES)
      request(:get, path, nil, retries: retries)
    end

    # @param path [String]
    # @param payload [Hash]
    # @return [Hash]
    def post(path, payload)
      request(:post, path, payload, retries: 0)
    end

    private

    def build_connection
      Faraday.new(url: SpreeWechatPay::API_HOST) do |faraday|
        faraday.options.open_timeout = OPEN_TIMEOUT
        faraday.options.timeout = READ_TIMEOUT
        faraday.adapter Faraday.default_adapter
      end
    end

    def request(verb, path, payload, retries:)
      body = payload ? JSON.generate(payload) : ''
      attempt = 0

      begin
        handle(perform(verb, path, body))
      rescue ConnectionError
        attempt += 1
        retry if attempt <= retries

        raise
      end
    end

    def perform(verb, path, body)
      @connection.public_send(verb, path) do |request|
        request.headers['Authorization'] = @context.signer.authorization_header(
          method: verb, path: path, body: body
        )
        request.headers['Accept'] = 'application/json'
        request.headers['Content-Type'] = 'application/json'
        request.body = body if body.present?
      end
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => error
      # Nothing came back, which is exactly the case the caller has to treat as
      # unknown rather than as a refusal.
      raise ConnectionError, "WeChat Pay could not be reached (#{error.class.name.demodulize})"
    end

    def handle(response)
      verify_response!(response)

      payload = parse(response.body)

      case response.status
      when 200..299
        payload
      when 400..499
        # WeChat named what was wrong with the request. Retrying an identical
        # request would be refused identically.
        #
        # The offending field is nested: `{"code":…,"message":…,"detail":{"field":
        # "/amount/currency","issue":…}}`. Reading it from the top level yields
        # nil for every rejection, and the `issue` is the half that says what to
        # change.
        detail = payload['detail'] || {}
        raise ApiError.new(
          payload['message'] || 'WeChat Pay rejected the request',
          code: payload['code'],
          field: detail['field'],
          issue: detail['issue'],
          status: response.status
        )
      else
        # A 5xx answers nothing about whether the request took effect, so it is
        # reported as unknown rather than as a failure.
        raise ConnectionError, "WeChat Pay answered #{response.status}"
      end
    end

    # WeChat signs every answer, and the signature is the whole of what makes an
    # answer WeChat's: without it a code_url, a transaction state or a
    # certificate could have been written by anything on the path. Checked
    # before the body is parsed, because there is no point reading a payload
    # that has not been attributed to anyone.
    def verify_response!(response)
      return if @verifier.blank?

      verifier = @verifier.respond_to?(:call) ? @verifier.call : @verifier
      return if verifier.blank?

      verifier.verify!(
        body: response.body.to_s,
        timestamp: response.headers['Wechatpay-Timestamp'].to_s,
        nonce: response.headers['Wechatpay-Nonce'].to_s,
        signature: response.headers['Wechatpay-Signature'].to_s,
        serial: response.headers['Wechatpay-Serial'].to_s
      )
    rescue Verifier::InvalidSignature => error
      raise VerificationError, "WeChat Pay answered with a signature that does not verify (#{error.message})"
    end

    def parse(body)
      return {} if body.blank?

      JSON.parse(body)
    rescue JSON::ParserError
      raise ConnectionError, 'WeChat Pay answered with a body that is not JSON'
    end
  end
end