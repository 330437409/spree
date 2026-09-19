module Spree
  module SellerRouting
    # Where there are sites — the reads a client makes when it has no seller
    # yet: the ones serving the province a point falls in, and the cities that
    # have sites at all.
    #
    # Both are one question over the same two tables, rolled up to the level
    # being asked about, and neither walks the tree: coverage is a subtree, and
    # a subtree is a code prefix because the codes are hierarchical by
    # construction (province two digits, city four, district six).
    class Sites
      COORDINATE_SYSTEM = 'gcj02'.freeze

      # The sellers serving the province the point falls in. A customer in no
      # seller's area still has to be shown what exists around them — it is what
      # the client's 未开通 page asks for, with the coordinate rather than a
      # province name.
      #
      # @param latitude [Numeric]
      # @param longitude [Numeric]
      # @param store [Spree::Store]
      # @return [ActiveRecord::Relation] sellable sellers
      def self.around(latitude:, longitude:, store:)
        resolution = Spree::ReverseGeocode::Resolve.call(
          latitude: latitude, longitude: longitude, source: COORDINATE_SYSTEM, store: store
        )

        province = Spree::AdministrativeDivision.find_by(code: resolution.path[:province])
        return Spree::Seller.none if province.nil?

        sellers_serving(province.subtree_code_prefix, store)
      end

      # The cities a site is bound in, for the client's location list. A binding
      # above the city level covers a province rather than one city, so it puts
      # no city on this list — the read above is what answers for it.
      #
      # @param store [Spree::Store]
      # @return [ActiveRecord::Relation] city-level administrative divisions
      def self.cities(store:)
        codes = serving_locations(store).
                joins(:administrative_division).
                pluck(Spree::AdministrativeDivision.arel_table[:code]).
                filter_map { |code| city_code_for(code) }.
                uniq

        Spree::AdministrativeDivision.at_level('city').where(code: codes).order(:first_pinyin)
      end

      def self.sellers_serving(code_prefix, store)
        Spree::Seller.sellable.
          where(store: store).
          joins(stock_locations: :administrative_division).
          where(Spree::StockLocation.table_name => { active: true }).
          where(Spree::AdministrativeDivision.arel_table[:code].matches("#{code_prefix}%")).
          distinct
      end
      private_class_method :sellers_serving

      def self.serving_locations(store)
        Spree::StockLocation.active.
          where(store: store).
          where(seller: Spree::Seller.sellable).
          where.not(administrative_division_id: nil)
      end
      private_class_method :serving_locations

      # A city code is its province's two digits and its own two, padded to the
      # six every code at that level has. Arithmetic rather than a query, and the
      # same arithmetic the tree is built on.
      def self.city_code_for(code)
        code = code.to_s
        return nil if code.length < 6

        "#{code[0, 4]}00"
      end
      private_class_method :city_code_for
    end
  end
end
