module Spree
  module SellerRouting
    # A warehouse's service-area polygon: GeoJSON linear rings in GCJ-02, as an
    # operator draws them in a map editor.
    #
    # It answers the four questions the write path and the match path ask — is
    # this usable geometry, which way round does it go, what is its bounding
    # box, and does it contain a point — without a geometry library. The shapes
    # are hand-drawn and small (tens of points), so the arithmetic is the
    # standard one: a segment-crossing test for self-intersection and a ray cast
    # for containment. That keeps the plugin portable across the three databases
    # this fork supports, none of which is asked to be a spatial database.
    #
    # Coordinates are GeoJSON's, so each point is `[longitude, latitude]`.
    class Polygon
      # Rings: the first is the outline and any others are holes, which GeoJSON
      # allows and a map editor can produce by accident.
      MINIMUM_RING_POINTS = 4

      attr_reader :rings, :errors

      # @param value [Array, String, nil] GeoJSON rings, or the JSON a json
      #   column hands back, which is the same thing once parsed
      # @return [Spree::SellerRouting::Polygon] usable or not — ask #valid?
      def initialize(value)
        @rings = parse(value)
        @errors = validate
      end

      # @return [Boolean] whether the geometry can be stored and matched against
      def valid?
        errors.empty?
      end

      # GeoJSON's right-hand rule: the outline runs counter-clockwise, holes run
      # clockwise. A hand-drawn ring arrives either way round, and refusing one
      # over an orientation nobody chose would fail an operator's polygon for no
      # reason — so the orientation is normalised rather than rejected.
      #
      # @return [Array<Array<Array<Float>>>] the rings, correctly wound
      def canonicalized
        return rings if rings.empty?

        rings.each_with_index.map do |ring, index|
          counter_clockwise?(ring) == index.zero? ? ring : ring.reverse
        end
      end

      # @return [Hash, nil] +{ min_lat:, max_lat:, min_lng:, max_lng: }+ — the
      #   pre-check that runs before a containment test
      def bounding_box
        points = rings.flatten(1)
        return nil if points.empty?

        lngs = points.map(&:first)
        lats = points.map(&:last)

        { min_lng: lngs.min, max_lng: lngs.max, min_lat: lats.min, max_lat: lats.max }
      end

      # Ray casting: a point is inside when a ray cast from it crosses the
      # outline an odd number of times. Holes are excluded afterwards, because
      # GeoJSON treats them as outside the polygon.
      #
      # @param latitude [Float] GCJ-02
      # @param longitude [Float] GCJ-02
      # @return [Boolean]
      def contains?(latitude:, longitude:)
        return false unless valid?
        return false unless bounding_box_contains?(latitude:, longitude:)
        return false unless ring_contains?(rings.first, longitude, latitude)

        rings.drop(1).none? { |hole| ring_contains?(hole, longitude, latitude) }
      end

      # @return [Boolean] the cheap test that precedes every containment check
      def bounding_box_contains?(latitude:, longitude:)
        box = bounding_box
        return false if box.nil?

        longitude.between?(box[:min_lng], box[:max_lng]) && latitude.between?(box[:min_lat], box[:max_lat])
      end

      private

      def parse(value)
        parsed = value.is_a?(String) ? JSON.parse(value) : value
        return [] unless parsed.is_a?(Array)

        parsed.map { |ring| ring.is_a?(Array) ? ring.map { |point| point.is_a?(Array) ? point.first(2) : point } : [] }
      rescue JSON::ParserError
        []
      end

      def validate
        return [:not_an_array] if rings.empty?

        rings.each_with_index.flat_map { |ring, index| ring_errors(ring, index) }
      end

      def ring_errors(ring, index)
        point = index.zero? ? :polygon : :polygon_hole
        errors = []

        errors << :too_few_points if ring.size < MINIMUM_RING_POINTS
        errors << :not_closed if ring.size >= MINIMUM_RING_POINTS && ring.first != ring.last
        errors << :not_a_point if ring.any? { |coordinate| !coordinate?(coordinate) }
        errors << :out_of_range if ring.any? { |coordinate| out_of_range?(coordinate) }
        errors << :self_intersecting if errors.empty? && self_intersecting?(ring)

        errors.map { |error| { attribute: point, error: error } }
      end

      def coordinate?(coordinate)
        coordinate.is_a?(Array) && coordinate.size == 2 && coordinate.all? { |value| value.is_a?(Numeric) && value.finite? }
      end

      def out_of_range?(coordinate)
        return false unless coordinate?(coordinate)

        longitude, latitude = coordinate
        !longitude.between?(-180, 180) || !latitude.between?(-90, 90)
      end

      # Every pair of segments that do not share an endpoint is tested for a
      # crossing. Adjacent segments are skipped: they meet at their shared
      # corner by construction, which is not an intersection.
      def self_intersecting?(ring)
        segments = ring.each_cons(2).to_a

        segments.each_with_index.any? do |segment, index|
          segments.each_with_index.any? do |other, other_index|
            next false if (index - other_index).abs <= 1
            next false if index.zero? && other_index == segments.size - 1
            next false if other_index.zero? && index == segments.size - 1

            segments_cross?(segment, other)
          end
        end
      end

      def segments_cross?(first, second)
        a, b = first
        c, d = second

        return false if [a, b].include?(c) || [a, b].include?(d)

        (orientation(a, b, c) * orientation(a, b, d)).negative? &&
          (orientation(c, d, a) * orientation(c, d, b)).negative?
      end

      def orientation(start, finish, point)
        (finish[0] - start[0]) * (point[1] - start[1]) - (finish[1] - start[1]) * (point[0] - start[0])
      end

      def ring_contains?(ring, longitude, latitude)
        inside = false
        ring.each_cons(2) do |(x1, y1), (x2, y2)|
          next unless (y1 > latitude) != (y2 > latitude)
          next if longitude >= [x1, x2].max

          intersection = (x2 - x1) * (latitude - y1) / (y2 - y1) + x1
          inside = !inside if longitude < intersection
        end
        inside
      end

      # The signed area's sign is the winding: positive is counter-clockwise in
      # a system with y up, which latitude is.
      def counter_clockwise?(ring)
        area = ring.each_cons(2).sum { |(x1, y1), (x2, y2)| (x2 - x1) * (y2 + y1) }
        area.negative?
      end
    end
  end
end
