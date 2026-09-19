module Spree
  module SellerRouting
    # Cost control at the door.
    #
    # The reverse-geocode cache is what makes a provider call rare; this keeps
    # one client from filling that cache — and spending the vendor's quota —
    # faster than anyone can pay for it. The endpoint is public and called
    # before sign-in, so there is nothing but the store and the caller's address
    # to count against.
    #
    # It fails open: a cache that cannot count must not take the endpoint down
    # with it, and the cache is still doing the heavy lifting underneath.
    class RateLimit
      # @param key [String] what is being limited, e.g. one store and one caller
      # @param limit [Integer] how many calls a window allows
      # @param window [ActiveSupport::Duration]
      # @return [Boolean] whether this call is allowed
      def self.allow?(key:, limit:, window:)
        count = Rails.cache.increment(key, 1, expires_in: window)
        count.nil? || count <= limit
      rescue NotImplementedError, ArgumentError
        true
      end
    end
  end
end
