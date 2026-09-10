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
    def initialize(context:, connection: nil)
      @context = context
      @connection = connection || build_connection
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
      payload = parse(response.body)

      case response.status
      when 200..299
        payload
      when 400..499
        # WeChat named what was wrong with the request. Retrying an identical
        # request would be refused identically.
        raise ApiError.new(
          payload['message'] || 'WeChat Pay rejected the request',
          code: payload['code'],
          field: payload['field'],
          status: response.status
        )
      else
        # A 5xx answers nothing about whether the request took effect, so it is
        # reported as unknown rather than as a failure.
        raise ConnectionError, "WeChat Pay answered #{response.status}"
      end
    end

    def parse(body)
      return {} if body.blank?

      JSON.parse(body)
    rescue JSON::ParserError
      raise ConnectionError, 'WeChat Pay answered with a body that is not JSON'
    end
  end
end
