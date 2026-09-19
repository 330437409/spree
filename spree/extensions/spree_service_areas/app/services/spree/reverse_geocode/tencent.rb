module Spree
  module ReverseGeocode
    # Tencent LBS, whose reverse geocoder answers a point with the names of the
    # divisions it falls in and one `adcode` — the code of the deepest division
    # it resolved, which is the bureau's own code for that level.
    #
    # @see https://lbs.qq.com/service/webService/webServiceGuide/webServiceGcoder
    class Tencent < Provider
      API_HOST = 'https://apis.map.qq.com'.freeze
      ENDPOINT = "#{API_HOST}/ws/geocoder/v1/".freeze

      # @param key [String, nil] the store's Tencent LBS key
      # @param client [Spree::ReverseGeocode::Client, nil] injected by specs
      def initialize(key: nil, client: nil)
        @key = key
        @client = client || Client.new
      end

      # @param latitude [Numeric] GCJ-02, as Tencent speaks
      # @param longitude [Numeric] GCJ-02
      # @return [Spree::ReverseGeocode::Result]
      # @raise [Spree::ReverseGeocode::ApiError] with the provider's own message
      def reverse_geocode(latitude:, longitude:)
        payload = @client.get(
          ENDPOINT,
          location: "#{latitude},#{longitude}",
          key: @key,
          get_poi: 0
        )
        raise ApiError.new(refusal_message(payload)) unless payload['status'].to_i.zero?

        build_result(payload['result'] || {}, latitude: latitude, longitude: longitude)
      end

      private

      def build_result(result, latitude:, longitude:)
        ad_info = result['ad_info'] || {}
        component = result['address_component'] || {}
        town = result.dig('address_reference', 'town') || {}

        Result.new(
          latitude: latitude,
          longitude: longitude,
          provider: provider_name,
          # The deepest division it resolved, which for a district is the code a
          # binding names. Province and city are the mapper's to derive: Tencent
          # answers those as names, not as codes.
          district_code: ad_info['adcode'].presence,
          province_name: ad_info['province'].presence || component['province'].presence,
          city_name: ad_info['city'].presence || component['city'].presence,
          district_name: ad_info['district'].presence || component['district'].presence,
          town_name: town['title'].presence
        )
      end

      # The provider's own words, kept: "此key每日调用量已达到上限" tells an
      # operator what to fix, and "the provider refused" does not.
      def refusal_message(payload)
        detail = payload['message'].presence || payload['status'].inspect
        "Tencent LBS refused the reverse geocoding request: #{detail}"
      end
    end
  end
end
