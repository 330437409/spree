module Spree
  module SellerRouting
    # Whether one warehouse serves one point — the rule routing and the coverage
    # check share.
    #
    # It is a collaborator rather than a private method of `Locate` because two
    # callers ask the same question about different subjects: routing asks it of
    # the candidates a query narrowed to, and the address check asks it of a
    # warehouse the customer named. One rule, so a point cannot be covered for
    # one caller and not the other.
    class Coverage
      # @param location [Spree::StockLocation] the binding warehouse
      # @param path [Hash<Symbol, String>] the resolved administrative path, as
      #   `ReverseGeocode::Resolve` answers it — every level carries its code, so
      #   a binding node is on the chain exactly when its code is in here
      # @param latitude [Numeric] GCJ-02
      # @param longitude [Numeric] GCJ-02
      # @return [Boolean]
      def self.covers?(location:, path:, latitude:, longitude:)
        node = location.administrative_division
        return false if node.nil?
        return false unless path.value?(node.code)

        polygon_covers?(location, latitude, longitude)
      end

      # No polygon means the bound node is the whole coverage. With one, the
      # stored bounding box answers first, so a candidate whose box excludes the
      # point never has its geometry parsed at all.
      def self.polygon_covers?(location, latitude, longitude)
        return true if location.polygon.blank?
        return false unless bounding_box_covers?(location, latitude, longitude)

        Spree::SellerRouting::Polygon.new(location.polygon).contains?(latitude: latitude, longitude: longitude)
      end

      def self.bounding_box_covers?(location, latitude, longitude)
        box = location.polygon_bbox
        return true if box.blank?

        longitude.to_f.between?(box['min_lng'].to_f, box['max_lng'].to_f) &&
          latitude.to_f.between?(box['min_lat'].to_f, box['max_lat'].to_f)
      end
      private_class_method :bounding_box_covers?
    end
  end
end
