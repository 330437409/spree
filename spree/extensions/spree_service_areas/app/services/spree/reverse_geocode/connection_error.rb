module Spree
  module ReverseGeocode
    # The vendor could not be reached, or answered something that is not an
    # answer. It says nothing about the point, so it is never cached.
    class ConnectionError < Error
      def initialize(message)
        super(message, code: :reverse_geocode_unreachable)
      end
    end
  end
end
