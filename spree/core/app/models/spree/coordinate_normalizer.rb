module Spree
  # The one place a coordinate changes systems.
  #
  # GCJ-02 is canonical here: the WeChat client, Tencent LBS and Amap all speak
  # it natively, and everything downstream — reverse geocoding, polygon tests,
  # distance — compares against it, so a pair is converted once at the edge
  # rather than guessed at by each consumer.
  #
  # The conversion is the published WGS-84 → GCJ-02 offset, written out rather
  # than taken from a gem: it is a dozen lines of arithmetic, it is the reason a
  # Chinese map lines up at all, and it is not what a dependency should be
  # carrying.
  class CoordinateNormalizer
    SOURCES = %w[gcj02 wgs84].freeze

    # Lookup services that already answer in GCJ-02, so a pair they produced
    # needs no conversion — the offset is only for the ones that do not.
    GCJ02_LOOKUPS = %w[tencent amap].freeze

    # The Krasovsky 1940 ellipsoid the offset is defined against.
    SEMI_MAJOR_AXIS = 6_378_245.0
    ECCENTRICITY_SQUARED = 0.006_693_421_622_965_943

    # China's bounding box, generously drawn. Outside it the offset does not
    # apply and the pair is returned untouched — an order shipped abroad keeps
    # the coordinates it came with.
    BOUNDS = { latitude: 3.86..53.55, longitude: 73.66..135.05 }.freeze

    # @param latitude [Numeric]
    # @param longitude [Numeric]
    # @param source [String, Symbol] the system the pair is in — `gcj02` or `wgs84`
    # @return [Array<Float>] the same point in GCJ-02
    # @raise [ArgumentError] when the source is not a system this class knows
    def self.normalize(latitude:, longitude:, source:)
      latitude = latitude.to_f
      longitude = longitude.to_f

      case source.to_s
      when 'gcj02' then [latitude, longitude]
      when 'wgs84' then wgs84_to_gcj02(latitude, longitude)
      else
        raise ArgumentError, "unknown coordinate system #{source.inspect}, expected one of #{SOURCES.join(', ')}"
      end
    end

    # Which system a lookup service answers in, so whoever geocoded through it
    # does not have to guess and this class stays the only place that knows.
    #
    # @param lookup [String, Symbol] the geocoder's lookup name
    # @return [String]
    def self.source_for_lookup(lookup)
      GCJ02_LOOKUPS.include?(lookup.to_s) ? 'gcj02' : 'wgs84'
    end

    # @param latitude [Float]
    # @param longitude [Float]
    # @return [Array<Float>]
    def self.wgs84_to_gcj02(latitude, longitude)
      return [latitude, longitude] unless inside_china?(latitude, longitude)

      latitude_offset = latitude_offset(longitude - 105.0, latitude - 35.0)
      longitude_offset = longitude_offset(longitude - 105.0, latitude - 35.0)

      radian_latitude = latitude / 180.0 * Math::PI
      magic = Math.sin(radian_latitude)**2
      magic = 1 - ECCENTRICITY_SQUARED * magic
      sqrt_magic = Math.sqrt(magic)

      latitude_offset = (latitude_offset * 180.0) /
                        ((SEMI_MAJOR_AXIS * (1 - ECCENTRICITY_SQUARED)) / (magic * sqrt_magic) * Math::PI)
      longitude_offset = (longitude_offset * 180.0) /
                         (SEMI_MAJOR_AXIS / sqrt_magic * Math.cos(radian_latitude) * Math::PI)

      [latitude + latitude_offset, longitude + longitude_offset]
    end

    def self.inside_china?(latitude, longitude)
      BOUNDS[:latitude].cover?(latitude) && BOUNDS[:longitude].cover?(longitude)
    end
    private_class_method :inside_china?

    def self.latitude_offset(x, y)
      offset = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * Math.sqrt(x.abs)
      offset += (20.0 * Math.sin(6.0 * x * Math::PI) + 20.0 * Math.sin(2.0 * x * Math::PI)) * 2.0 / 3.0
      offset += (20.0 * Math.sin(y * Math::PI) + 40.0 * Math.sin(y / 3.0 * Math::PI)) * 2.0 / 3.0
      offset + (160.0 * Math.sin(y / 12.0 * Math::PI) + 320.0 * Math.sin(y * Math::PI / 30.0)) * 2.0 / 3.0
    end
    private_class_method :latitude_offset

    def self.longitude_offset(x, y)
      offset = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * Math.sqrt(x.abs)
      offset += (20.0 * Math.sin(6.0 * x * Math::PI) + 20.0 * Math.sin(2.0 * x * Math::PI)) * 2.0 / 3.0
      offset += (20.0 * Math.sin(x * Math::PI) + 40.0 * Math.sin(x / 3.0 * Math::PI)) * 2.0 / 3.0
      offset + (150.0 * Math.sin(x / 12.0 * Math::PI) + 300.0 * Math.sin(x / 30.0 * Math::PI)) * 2.0 / 3.0
    end
    private_class_method :longitude_offset
  end
end
