module Spree
  module SellerRouting
    # Which seller serves a coordinate — the one service that answers the
    # question the client asks, above the reverse geocoding and the bindings.
    #
    # The point is placed in the tree first, so covering it is a membership test
    # over that leaf's ancestor chain rather than a subtree query: a warehouse
    # covers the point exactly when its bound node is one of the chain's nodes.
    # Candidates are then ordered deepest first, and the first whose polygon (if
    # it has one) contains the point wins — so a township binding beats the
    # district above it, and two points in the same cell always answer the same
    # warehouse.
    class Locate
      COORDINATE_SYSTEM = 'gcj02'.freeze

      # @param latitude [Numeric]
      # @param longitude [Numeric]
      # @param source [String, Symbol] the system the pair arrives in
      # @param store [Spree::Store]
      # @return [Spree::SellerRouting::Decision]
      # @raise [Spree::ReverseGeocode::Error] when the point cannot be placed
      #   and no cached answer exists
      def self.call(latitude:, longitude:, source: 'gcj02', store: Spree::Current.store)
        new(latitude: latitude, longitude: longitude, source: source, store: store).call
      end

      def initialize(latitude:, longitude:, source:, store:)
        @latitude, @longitude = Spree::CoordinateNormalizer.normalize(
          latitude: latitude, longitude: longitude, source: source
        )
        @store = store
      end

      def call
        resolution = Spree::ReverseGeocode::Resolve.call(
          latitude: @latitude, longitude: @longitude, source: COORDINATE_SYSTEM, store: @store
        )
        offered = candidates(resolution.path).to_a
        # Counted rather than stopped at: a shop whose polygon turned a customer
        # away is the first thing anyone asks about when routing looks wrong.
        matched = nil
        rejections = 0
        offered.each do |location|
          if Coverage.covers?(location: location, path: resolution.path, latitude: @latitude, longitude: @longitude)
            matched = location
            break
          end

          rejections += 1 if location.polygon.present?
        end

        decision_for(matched, resolution: resolution, candidate_count: offered.size, polygon_rejections: rejections)
      end

      private

      # Only a seller's warehouse can serve a buyer: the operator's own stock is
      # allocated by the fulfillment routing, not discovered this way. A seller
      # still onboarding, suspended or away is not sellable, and neither is an
      # inactive warehouse — the same gates the seller profile reads use.
      def candidates(path)
        division_ids = ids_for(path)
        return Spree::StockLocation.none if division_ids.empty?

        Spree::StockLocation.active
                            .joins(:administrative_division)
                            .where(administrative_division_id: division_ids)
                            .where(seller: Spree::Seller.sellable)
                            .order(Spree::AdministrativeDivision.arel_table[:depth].desc)
                            .order(Spree::StockLocation.arel_table[:id].asc)
      end

      def ids_for(path)
        codes = path.values.compact
        return [] if codes.empty?

        Spree::AdministrativeDivision.where(code: codes).pluck(:id)
      end

      def decision_for(location, resolution:, candidate_count:, polygon_rejections:)
        working = {
          stale: resolution.stale?,
          cached: resolution.cached?,
          provider: resolution.provider,
          candidate_count: candidate_count,
          polygon_rejections: polygon_rejections,
          resolved_division_code: resolution.path.values.compact.last
        }

        return Decision.new(**working) if location.nil?

        division = location.administrative_division

        Decision.new(
          **working,
          seller: location.seller,
          stock_location: location,
          division: division,
          match_type: division.level,
          polygon_result: location.polygon.present? ? 'matched' : 'not_required',
          distance_km: distance_to(location)
        )
      end

      # Where the shop is, from where the buyer is — shown, never matched on.
      def distance_to(location)
        return nil if location.latitude.nil? || location.longitude.nil?

        Geocoder::Calculations.distance_between(
          [@latitude, @longitude], [location.latitude.to_f, location.longitude.to_f], units: :km
        ).round(2)
      end
    end
  end
end
