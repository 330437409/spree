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
        path = resolution.path

        warehouse = candidates(path).find do |location|
          Coverage.covers?(location: location, path: path, latitude: @latitude, longitude: @longitude)
        end

        decision_for(warehouse, stale: resolution.stale?)
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

      def decision_for(location, stale:)
        return Decision.new(stale: stale) if location.nil?

        division = location.administrative_division

        Decision.new(
          seller: location.seller,
          stock_location: location,
          division: division,
          match_type: division.level,
          polygon_result: location.polygon.present? ? 'matched' : 'not_required',
          distance_km: distance_to(location),
          stale: stale
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
