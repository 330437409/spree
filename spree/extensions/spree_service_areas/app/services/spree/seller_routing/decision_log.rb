module Spree
  module SellerRouting
    # What the routing tells the world about the answer it gave.
    #
    # One event per request, on `ActiveSupport::Notifications`, so a deployment's
    # own subscriber — a log line, a span, a counter — reads it without this gem
    # knowing which one it is. It answers "why did this customer land on this
    # seller": which provider placed the point, whether the answer was cached,
    # how many warehouses were considered and which one won.
    #
    # **The coordinate travels as a cell, never as itself.** A five-character
    # geohash names a neighbourhood rather than a person, and the question the
    # log exists to answer does not need to know where anyone was standing.
    #
    # The plan's metrics read this event: `cache_hit: false` is
    # `seller_routing_cache_misses_total`, `matched: false` is
    # `seller_routing_no_match_total`, `polygon_rejections` and `latency_ms` are
    # their own, and a failure carries the provider's error code.
    class DecisionLog
      NOTIFICATION = 'locate.spree_seller_routing'.freeze

      # Roughly five kilometres: enough to say which part of a city, not enough
      # to say which doorway.
      CELL_PRECISION = 5

      # @param decision [Spree::SellerRouting::Decision]
      # @param latitude [Numeric] the point as asked about
      # @param longitude [Numeric]
      # @param request_id [String, nil]
      # @param latency_ms [Numeric, nil]
      def self.publish(decision:, latitude:, longitude:, request_id: nil, latency_ms: nil)
        instrument(
          request_id: request_id,
          latitude: latitude,
          longitude: longitude,
          latency_ms: latency_ms,
          provider: decision.provider,
          cache_hit: decision.cached?,
          stale: decision.stale?,
          resolved_division: decision.resolved_division_code,
          candidate_count: decision.candidate_count,
          selected_division: decision.division&.code,
          selected_warehouse: decision.stock_location&.prefixed_id,
          seller: decision.seller&.prefixed_id,
          matched: decision.matched?,
          match_type: decision.match_type,
          polygon_result: decision.polygon_result,
          polygon_rejections: decision.polygon_rejections,
          distance_km: decision.distance_km
        )
      end

      # The other outcome: no provider could answer and nothing was cached, so
      # there is no decision to report — only why there is none. The provider's
      # own error code travels, which is what separates "the key expired" from
      # "the network is down" on a dashboard.
      #
      # @param error [Spree::ReverseGeocode::Error]
      def self.publish_failure(error:, latitude:, longitude:, request_id: nil, latency_ms: nil)
        instrument(
          request_id: request_id,
          latitude: latitude,
          longitude: longitude,
          latency_ms: latency_ms,
          matched: false,
          error_code: error.code,
          error_message: error.message
        )
      end

      def self.instrument(latitude:, longitude:, **payload)
        ActiveSupport::Notifications.instrument(
          NOTIFICATION,
          **payload,
          coordinate_hash: Spree::ReverseGeocode::Geohash.encode(
            latitude: latitude, longitude: longitude, precision: CELL_PRECISION
          )
        )
      end
      private_class_method :instrument
    end
  end
end
