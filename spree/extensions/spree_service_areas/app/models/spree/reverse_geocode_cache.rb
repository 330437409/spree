module Spree
  # One answered cell of the world.
  #
  # Vendors bill per call and the same cell is asked about by every customer
  # standing in it, so an answer is kept — including an answer of "nothing here",
  # because an edge area that resolves to no division is exactly the one that
  # would be asked about again and again. The entry is not an invalidation
  # problem: the key carries the provider, the coordinate system and the tree
  # release, so a change to any of them is a different row rather than a row to
  # clear.
  class ReverseGeocodeCache < Spree.base_class
    # Roughly 150 m by 150 m — small enough that a cell does not straddle two
    # districts in a way a customer would notice, wide enough that a street's
    # worth of customers share one call.
    GEOHASH_PRECISION = 7

    # The systems a cached answer can be expressed in. Only the canonical one is
    # ever asked for; the column exists so a future provider that must be spoken
    # to in another system does not silently share a row with this one.
    COORDINATE_SYSTEMS = %w[gcj02 wgs84].freeze

    validates :geohash, :provider, :coordinate_system, :dataset_version, :expires_at, presence: true
    validates :coordinate_system, inclusion: { in: COORDINATE_SYSTEMS }

    scope :fresh, -> { where(expires_at: Time.current..) }
    scope :expired, -> { where(expires_at: ...Time.current) }

    # @return [Hash<Symbol, String>, nil] the path this cell resolves to, or nil
    #   when the provider found nothing here
    def path
      return nil unless resolved?

      { country: Spree::AdministrativeDivision::ROOT_CODE, province: province_code,
        city: city_code, district: district_code, township: township_code }.compact
    end
  end
end
