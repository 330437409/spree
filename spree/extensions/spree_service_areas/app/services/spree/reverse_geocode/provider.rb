module Spree
  module ReverseGeocode
    # What a vendor adapter answers with and what everything above it is
    # written against — so adding Amap is a class, not a change to the
    # resolution, the cache key or the API.
    class Provider
      # A vendor is a provider and a mapper, registered under the name a store
      # configures. Adding one is a row plus the two classes — never a change to
      # the resolution, the cache key or the API, and never a class name in a
      # request or a setting.
      #
      # Registered rather than listed in a constant so that another gem can add
      # a vendor without editing this file.
      def self.registry
        @registry ||= {
          'tencent' => {
            provider: 'Spree::ReverseGeocode::Tencent',
            mapper: 'Spree::ReverseGeocode::TencentMapper'
          }
        }
      end

      # @param name [String, Symbol] the name a store configures
      # @param provider [String] the adapter's class name
      # @param mapper [String] the class that maps this vendor's codes
      def self.register(name, provider:, mapper:)
        registry[name.to_s] = { provider: provider, mapper: mapper }
      end

      # @param name [String, Symbol]
      # @return [Hash<Symbol, String>]
      # @raise [Spree::ReverseGeocode::UnknownProviderError]
      def self.registered(name)
        registry[name.to_s] || raise(UnknownProviderError.new(name))
      end

      # @param latitude [Numeric] canonical GCJ-02
      # @param longitude [Numeric] canonical GCJ-02
      # @return [Spree::ReverseGeocode::Result]
      def reverse_geocode(latitude:, longitude:)
        raise NotImplementedError
      end

      # The name this provider is configured and cached under.
      #
      # @return [String]
      def self.provider_name
        name.demodulize.underscore
      end

      # @return [String]
      def provider_name
        self.class.provider_name
      end
    end
  end
end
