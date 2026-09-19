module Spree
  module ReverseGeocode
    # Coordinates in, administrative path out.
    #
    # The only place that decides whether a vendor is called at all: the cache
    # answers first, the configured provider is asked when it does not, the
    # store's fallback is asked when the first one refuses, and a cached answer
    # — even an expired one — is served when both are unreachable. A request
    # fails only when there is nothing to answer with.
    #
    # Callers hand over coordinates in whatever system they have them and get a
    # path in bureau codes; nothing above this knows which vendor answered,
    # which is what makes a second vendor a configuration change.
    class Resolve
      COORDINATE_SYSTEM = 'gcj02'.freeze

      # @param latitude [Numeric]
      # @param longitude [Numeric]
      # @param source [String, Symbol] the system the pair arrives in
      # @param store [Spree::Store] whose provider settings and key are used
      # @param providers [Hash<String, Spree::ReverseGeocode::Provider>] injected by specs
      # @return [Spree::ReverseGeocode::Resolution]
      # @raise [Spree::ReverseGeocode::Error] when no provider answered and nothing was cached
      def self.call(latitude:, longitude:, source:, store:, providers: {})
        new(latitude:, longitude:, source:, store:, providers:).call
      end

      def initialize(latitude:, longitude:, source:, store:, providers: {})
        @latitude, @longitude = Spree::CoordinateNormalizer.normalize(latitude:, longitude:, source:)
        @store = store
        @providers = providers
      end

      def call
        cached = entry(fresh: true)
        return resolution_from(cached) if cached

        begin
          provider_name, result = ask(@store.preferred_reverse_geocode_provider)
        rescue Error
          # Both vendors refused. What was cached is the last thing anyone knew
          # about this cell, and the tree it was resolved against is a release
          # rather than a moving target — so it is served, and it says it is old.
          stale = entry(fresh: false)
          raise unless stale

          return resolution_from(stale, stale: true)
        end

        resolve(provider_name, result)
      end

      private

      # Whichever vendor answers is the one the answer is attributed to: the
      # fallback's answer is cached and reported under the fallback, because
      # that is what produced it — and the next request for this cell asks it
      # first for that reason.
      #
      # @return [Array(String, Spree::ReverseGeocode::Result)]
      def ask(primary_name)
        [primary_name, attempt(primary_name)]
      rescue Error => primary_error
        fallback_name = @store.preferred_reverse_geocode_fallback_provider
        raise primary_error if fallback_name.blank?

        [fallback_name, attempt(fallback_name) || raise(primary_error)]
      end

      def attempt(name)
        raise UnknownProviderError.new(name) if name.blank?

        provider_for(name).reverse_geocode(latitude: @latitude, longitude: @longitude)
      end

      def provider_for(name)
        @providers[name.to_s] || Provider.registered(name)[:provider].constantize.new(key: api_key_for(name))
      end

      def api_key_for(name)
        preference = :"reverse_geocode_#{name}_key"
        return nil unless @store.has_preference?(preference)

        @store.get_preference(preference)
      end

      def resolve(provider_name, result)
        codes = Provider.registered(provider_name)[:mapper].constantize.new.call(result)
        path = Normalizer.call(result: result, codes: codes)

        cache(provider_name, path: path)

        Resolution.new(path: path, provider: provider_name)
      end

      # Upsert by hand rather than `upsert_all`: the conflict target has to be
      # named on PostgreSQL and SQLite and must not be on MySQL, and this is one
      # row per lookup rather than a batch.
      def cache(provider_name, path:)
        entry = Spree::ReverseGeocodeCache.find_or_initialize_by(
          geohash: geohash,
          provider: provider_name,
          coordinate_system: COORDINATE_SYSTEM,
          dataset_version: dataset_version
        )

        entry.assign_attributes(
          resolved: path.present?,
          province_code: path[:province],
          city_code: path[:city],
          district_code: path[:district],
          township_code: path[:township],
          expires_at: expires_at
        )
        entry.save!
      end

      # Both configured vendors are checked, because the answer may well have
      # come from the fallback the last time this cell was asked about.
      def entry(fresh:)
        providers = [@store.preferred_reverse_geocode_provider,
                     @store.preferred_reverse_geocode_fallback_provider].compact.uniq

        providers.each do |provider|
          scope = Spree::ReverseGeocodeCache.where(
            geohash: geohash,
            provider: provider,
            coordinate_system: COORDINATE_SYSTEM,
            dataset_version: dataset_version
          )
          scope = scope.fresh if fresh

          found = scope.order(expires_at: :desc).first
          return found if found
        end

        nil
      end

      def resolution_from(entry, stale: false)
        Resolution.new(path: entry.path || {}, provider: entry.provider, cached: true, stale: stale)
      end

      def geohash
        @geohash ||= Geohash.encode(latitude: @latitude, longitude: @longitude)
      end

      def dataset_version
        @dataset_version ||= Spree::AdministrativeDivision.current_dataset_version
      end

      def expires_at
        Time.current + @store.preferred_reverse_geocode_ttl_days.to_i.days
      end
    end
  end
end
