module Spree
  module ReverseGeocode
    # A refusal a caller can act on: the message says what went wrong in the
    # provider's own terms, and the code is what the API surface answers with.
    class Error < StandardError
      attr_reader :code

      def initialize(message, code:)
        @code = code
        super(message)
      end
    end
  end
end
