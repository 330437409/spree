require 'digest'

module Spree
  module VerificationCodes
    # The bucket that stops SMS pumping: many addresses, one number range, one
    # bill. The API's own limit is keyed by a client's IP and cannot see that,
    # and the client's only guard is a flag it sets for itself.
    #
    # In the cache rather than in the codes table, because this is a fact about
    # the last ten minutes rather than a record of anything — and the number is
    # held as a digest, since a cache key is not a place to collect phone
    # numbers either.
    class PhoneRateLimit
      # Ten minutes is the client's own resend window with room for a retry,
      # and the day's ceiling is what bounds one number's bill.
      WINDOWS = [
        { name: 'short', limit: 3, window: 10.minutes },
        { name: 'day', limit: 10, window: 1.day }
      ].freeze

      # The store is part of the key: one store's sends must not spend
      # another's budget, and a merchant reading their own bill should see
      # their own traffic.
      #
      # @param store [Spree::Store]
      # @param phone [String] normalized
      # @return [Boolean]
      def self.exceeded?(store:, phone:)
        WINDOWS.any? { |window| count(store: store, phone: phone, window: window) >= window[:limit] }
      end

      # @param store [Spree::Store]
      # @param phone [String] normalized
      # @return [void]
      def self.record(store:, phone:)
        WINDOWS.each do |window|
          key = cache_key(store, phone, window)
          # `increment` starts a counter only where the store does; where it
          # answers nil the key is not there yet and the window opens now.
          Rails.cache.increment(key, 1, expires_in: window[:window]) ||
            Rails.cache.write(key, 1, expires_in: window[:window])
        end
      end

      # @return [Integer]
      def self.count(store:, phone:, window:)
        Rails.cache.read(cache_key(store, phone, window)).to_i
      end

      # @return [String]
      def self.cache_key(store, phone, window)
        "verification_codes/#{store.id}/#{window[:name]}/#{Digest::SHA256.hexdigest(phone)[0, 32]}"
      end

      private_class_method :count, :cache_key
    end
  end
end
