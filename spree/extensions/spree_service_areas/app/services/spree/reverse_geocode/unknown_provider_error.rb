module Spree
  module ReverseGeocode
    # A store is configured with a provider nothing is registered under, or with
    # none at all. Misconfiguration rather than an outage, and it says which.
    class UnknownProviderError < Error
      def initialize(provider)
        message = if provider.blank?
                    'No reverse geocoding provider is configured for this store'
                  else
                    "No reverse geocoding provider is registered as #{provider.inspect}"
                  end

        super(message, code: :reverse_geocode_provider_unknown)
      end
    end
  end
end
