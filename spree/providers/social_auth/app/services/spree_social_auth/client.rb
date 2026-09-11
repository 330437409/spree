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
    # @return [Hash] the parsed body
    def get(url, params)
      request(:get, url, params)
    end

    # @param url [String]
    # @param params [Hash]
    # @return [Hash] the parsed body
    def post(url, params)
      request(:post, url, params)
    end

    private

    def request(verb, url, params)
      response = verb == :post ? post_request(url, params) : @connection.get(url, params)

      parse(response.body)
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      raise ConnectionError, "The provider could not be reached (#{e.class.name.demodulize})"
    end

    # Encoded here rather than left to Faraday's middleware: both providers that
    # post do it as a form, and a Hash handed straight to #post is not a body
    # Faraday can send.
    def post_request(url, params)
      @connection.post(url) do |request|
        request.headers['Content-Type'] = 'application/x-www-form-urlencoded'
        request.body = URI.encode_www_form(params)
      end
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
