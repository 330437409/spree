module Spree
  module ReverseGeocode
    # The provider's answer and the mapper's codes in one shape: the
    # administrative path a service area is matched against, country first.
    #
    # It is a shape rather than a translation — the levels a vendor did not
    # resolve are absent, not guessed, so a point the provider only placed in a
    # city matches a binding on that city and nothing deeper.
    class Normalizer
      # @param result [Spree::ReverseGeocode::Result]
      # @param codes [Hash<Symbol, String>] the mapper's bureau codes
      # @return [Hash<Symbol, String>] the resolved path, deepest level last
      def self.call(result:, codes:)
        new(result: result, codes: codes).call
      end

      def initialize(result:, codes:)
        @result = result
        @codes = codes
      end

      def call
        # Nothing resolved is an empty path rather than a country: a pair in the
        # middle of the ocean is not in China, and a path that says it is would
        # match a nationwide seller for a point outside the country.
        return {} if @codes.empty?

        {
          country: Spree::AdministrativeDivision::ROOT_CODE,
          province: @codes[:province],
          city: @codes[:city],
          district: @codes[:district],
          township: @codes[:township]
        }.compact
      end
    end
  end
end
