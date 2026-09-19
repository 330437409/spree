module Spree
  module ReverseGeocode
    # The vendor answered, and the answer was a refusal — an expired key, a
    # quota reached, a request it would not serve. Its own words are kept.
    class ApiError < Error
      def initialize(message)
        super(message, code: :reverse_geocode_refused)
      end
    end
  end
end
