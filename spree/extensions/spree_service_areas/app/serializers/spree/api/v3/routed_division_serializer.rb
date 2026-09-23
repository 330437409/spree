module Spree
  module Api
    module V3
      # The node the routing matched: what it is called and what it is.
      #
      # It is deliberately not the picker's serializer — that one carries the
      # romanisation a customer browses by and whether asking again is worth a
      # round trip, and none of it is a fact about where a seller delivers.
      class RoutedDivisionSerializer
        include Alba::Resource

        attributes :code, :name, :level
      end
    end
  end
end
