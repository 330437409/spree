module Spree
  module ReverseGeocode
    # The cell a coordinate falls in, as a short string.
    #
    # Two customers standing on the same street corner share it, which is what
    # makes one provider call serve both — and a cell boundary is a boundary of
    # about 150 m at the precision the cache uses, so nobody notices they are
    # on different sides of one.
    #
    # @see https://en.wikipedia.org/wiki/Geohash
    class Geohash
      BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz'.freeze

      # @param latitude [Numeric]
      # @param longitude [Numeric]
      # @param precision [Integer] characters, each worth five bits
      # @return [String]
      def self.encode(latitude:, longitude:, precision: Spree::ReverseGeocodeCache::GEOHASH_PRECISION)
        latitude_range = [-90.0, 90.0]
        longitude_range = [-180.0, 180.0]

        hash = +''
        bits = 0
        bit_count = 0
        divide_longitude = true

        while hash.length < precision
          if divide_longitude
            midpoint = (longitude_range[0] + longitude_range[1]) / 2
            if longitude.to_f >= midpoint
              bits = (bits << 1) | 1
              longitude_range[0] = midpoint
            else
              bits <<= 1
              longitude_range[1] = midpoint
            end
          else
            midpoint = (latitude_range[0] + latitude_range[1]) / 2
            if latitude.to_f >= midpoint
              bits = (bits << 1) | 1
              latitude_range[0] = midpoint
            else
              bits <<= 1
              latitude_range[1] = midpoint
            end
          end

          divide_longitude = !divide_longitude
          bit_count += 1

          next unless bit_count == 5

          hash << BASE32[bits]
          bits = 0
          bit_count = 0
        end

        hash
      end
    end
  end
end
