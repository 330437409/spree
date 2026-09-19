module Spree
  module SellerRouting
    # What the routing decided, in one object: the seller, the warehouse whose
    # binding produced the match, the division that matched, how deep it was,
    # the polygon's verdict and the display distance.
    #
    # A decision with no seller is a decision and not an error — "no service
    # here" is a state the client renders in its own words, and telling it apart
    # from a failure matters to whoever is on call.
    class Decision
      attr_reader :seller, :stock_location, :division, :match_type, :polygon_result, :distance_km

      # @param seller [Spree::Seller, nil]
      # @param stock_location [Spree::StockLocation, nil] the binding warehouse
      # @param division [Spree::AdministrativeDivision, nil] the matched node
      # @param match_type [String, nil] the matched node's level
      # @param polygon_result [String, nil] 'matched' | 'not_required'
      # @param distance_km [Float, nil] display only — never a matching input
      # @param stale [Boolean] the geocoding behind this decision came from an
      #   expired cache entry, because no provider answered
      def initialize(seller: nil, stock_location: nil, division: nil, match_type: nil,
                     polygon_result: nil, distance_km: nil, stale: false)
        @seller = seller
        @stock_location = stock_location
        @division = division
        @match_type = match_type
        @polygon_result = polygon_result
        @distance_km = distance_km
        @stale = stale
      end

      def matched?
        seller.present?
      end

      # @return [Integer, nil] how deep the matched binding sits in the tree
      def depth
        division&.depth
      end

      def stale?
        @stale
      end
    end
  end
end
