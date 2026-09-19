require 'faraday'

module Spree
  module ReverseGeocode
    # The HTTP layer the providers share: short timeouts, because the call sits
    # inside a shopper's request, JSON parsing, and the two failures a provider
    # turns into something a person can read.
    class Client
      OPEN_TIMEOUT = 3
      READ_TIMEOUT = 5

      # @param connection [Faraday::Connection, nil] injected by specs
      def initialize(connection: nil)
        @connection = connection || build_connection
      end

      # @param url [String] absolute URL, so a provider carries its own host
      # @param params [Hash]
      # @return [Hash] the parsed body
      def get(url, params)
        response = @connection.get(url, params)
        raise_for_status(response)

        parse(response.body)
      rescue Faraday::Error => error
        # Faraday::Error is the whole family — timeouts, connection failures,
        # TLS refusals, redirect loops — so a provider that fails in a way
        # nobody enumerated is still a named refusal rather than a 500.
        raise ConnectionError, "The geocoding provider could not be reached (#{error.class.name.demodulize})"
      end

      private

      def raise_for_status(response)
        return if response.success?

        raise ApiError.new("The geocoding provider refused the request (HTTP #{response.status})")
      end

      def parse(body)
        raise ConnectionError, 'The geocoding provider answered with a body that is not JSON' if body.blank?

        JSON.parse(body)
      rescue JSON::ParserError
        raise ConnectionError, 'The geocoding provider answered with a body that is not JSON'
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
end
