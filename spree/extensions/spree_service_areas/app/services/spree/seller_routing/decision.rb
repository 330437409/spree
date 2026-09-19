module Spree
  module SellerRouting
    # What the routing decided, in one object: the seller, the warehouse whose
    # binding produced the match, the division that matched, how deep it was,
    # the polygon's verdict and the display distance.
    #
    # A decision with no seller is a decision and not an error — "no service
    # here" is a state the client renders in its own words, and telling it apart
    # from a failure matters to whoever is on call.
    #
    # It carries what it decided *and* what it decided it from — the resolved
    # division, the candidate count, whether the geocoding was cached — because
    # the decision log is written from here and a log that cannot say why is a
    # log nobody reads. None of that reaches the customer: the serializer renders
    # the answer, not the working.
    class Decision
      attr_reader :seller, :stock_location, :division, :match_type, :polygon_result,
                  :distance_km, :candidate_count, :resolved_division_code, :provider,
                  :polygon_rejections

      # @param seller [Spree::Seller, nil]
      # @param stock_location [Spree::StockLocation, nil] the binding warehouse
      # @param division [Spree::AdministrativeDivision, nil] the matched node
      # @param match_type [String, nil] the matched node's level
      # @param polygon_result [String, nil] 'matched' | 'not_required'
      # @param distance_km [Float, nil] display only — never a matching input
      # @param stale [Boolean] the geocoding behind this decision came from an
      #   expired cache entry, because no provider answered
      # @param cached [Boolean] the geocoding was answered from the cache
      # @param candidate_count [Integer] how many warehouses the query offered
      # @param resolved_division_code [String, nil] what the point resolved to,
      #   as opposed to what matched — the two differ whenever nothing covered it
      # @param provider [String, nil] which vendor placed the point
      # @param polygon_rejections [Integer] candidates a polygon turned away
      def initialize(seller: nil, stock_location: nil, division: nil, match_type: nil,
                     polygon_result: nil, distance_km: nil, stale: false, cached: false,
                     candidate_count: 0, resolved_division_code: nil, provider: nil,
                     polygon_rejections: 0)
        @seller = seller
        @stock_location = stock_location
        @division = division
        @match_type = match_type
        @polygon_result = polygon_result
        @distance_km = distance_km
        @stale = stale
        @cached = cached
        @candidate_count = candidate_count
        @resolved_division_code = resolved_division_code
        @provider = provider
        @polygon_rejections = polygon_rejections
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

      def cached?
        @cached
      end
    end
  end
end
