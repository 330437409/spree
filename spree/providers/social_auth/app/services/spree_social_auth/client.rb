module SpreeSocialAuth
  # The HTTP layer the provider strategies share: short timeouts (these calls
  # run inside a shopper's request), JSON parsing, and the two errors a strategy
  # translates into something a person can act on.
  class Client
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10

    # @param connection [Faraday::Connection, nil] injected by specs
    def initialize(connection: nil)
      @connection = connection || build_connection
    end

    # @param url [String]
    # @param params [Hash]
    # @param headers [Hash]
    # @return [Hash] the parsed body
    def get(url, params, headers: {})
      request(:get, url, params, headers)
    end

    # @param url [String]
    # @param params [Hash]
    # @param headers [Hash]
    # @return [Hash] the parsed body
    def post(url, params, headers: {})
      request(:post, url, params, headers)
    end

    private

    def request(verb, url, params, headers)
      response = verb == :post ? post_request(url, params, headers) : @connection.get(url, params, headers)
      raise_for_status(response)

      parse(response.body)
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      raise ConnectionError, "The provider could not be reached (#{e.class.name.demodulize})"
    end

    # Encoded here rather than left to Faraday's middleware: both providers that
    # post do it as a form, and a Hash handed straight to #post is not a body
    # Faraday can send.
    def post_request(url, params, headers)
      @connection.post(url) do |request|
        request.headers.merge!(headers) if headers.present?
        request.headers['Content-Type'] = 'application/x-www-form-urlencoded'
        request.body = URI.encode_www_form(params)
      end
    end

    # A provider that refuses with a real status must not be read as a success:
    # the flow would carry on with an empty token and fail somewhere that names
    # nothing useful. WeChat and Douyin always answer 200, so this never fires
    # for them.
    def raise_for_status(response)
      return if response.success?

      raise ApiError.new("The provider refused the request (HTTP #{response.status}#{detail_suffix(response.body)})")
    end

    def detail_suffix(body)
      error = JSON.parse(body.to_s)
      detail = [error['error'], error['error_description']].map(&:presence).compact.uniq.join(': ')

      detail.present? ? ": #{detail}" : ''
    rescue StandardError
      ''
    end

    def parse(body)
      raise ConnectionError, 'The provider answered with a body that is not JSON' if body.blank?

      JSON.parse(body)
    rescue JSON::ParserError
      raise ConnectionError, 'The provider answered with a body that is not JSON'
    end

    def build_connection
      Faraday.new do |faraday|
        faraday.options.open_timeout = OPEN_TIMEOUT
        faraday.options.timeout = READ_TIMEOUT
        faraday.adapter Faraday.default_adapter
      end
    end
  end
end
