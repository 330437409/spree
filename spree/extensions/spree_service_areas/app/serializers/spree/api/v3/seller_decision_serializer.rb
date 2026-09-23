module Spree
  module Api
    module V3
      # The routing decision as the client reads it.
      #
      # `matched: false` is a complete answer, not a failure: the client has
      # three states of its own to show for it, and which words it uses is its
      # business. The matched division and the polygon's verdict are here so a
      # wrong answer can be diagnosed without a console.
      #
      # It does not inherit `BaseSerializer`, which is written for records: a
      # decision has no id, no timestamps and nothing to expand.
      class SellerDecisionSerializer
        include Alba::Resource
        include Typelizer::DSL

        typelize matched: :boolean, match_type: [:string, nullable: true],
                 seller: 'Seller | null', administrative_division: 'AdministrativeDivision | null',
                 warehouse: 'Site | null',
                 polygon_result: [:string, nullable: true], stale: :boolean,
                 distance_km: [:number, nullable: true]

        attribute :matched do |decision|
          decision.matched?
        end

        attribute :match_type do |decision|
          decision.match_type
        end

        attribute :polygon_result do |decision|
          decision.polygon_result
        end

        # The geocoding behind this answer came from an expired cache entry
        # because every provider was unreachable. The customer keeps working;
        # whoever is on call can see why the answer is old.
        attribute :stale do |decision|
          decision.stale?
        end

        attribute :distance_km do |decision|
          decision.distance_km
        end

        attribute :seller do |decision|
          next nil if decision.seller.nil?

          Spree.api.seller_serializer.new(decision.seller, params: params).to_h
        end

        attribute :administrative_division do |decision|
          next nil if decision.division.nil?

          RoutedDivisionSerializer.new(decision.division, params: params).to_h
        end

        attribute :warehouse do |decision|
          next nil if decision.stock_location.nil?

          Spree.api.seller_stock_location_serializer.new(decision.stock_location, params: params).to_h
        end
      end
    end
  end
end
