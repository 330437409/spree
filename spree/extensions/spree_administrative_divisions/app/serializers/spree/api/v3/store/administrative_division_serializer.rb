module Spree
  module Api
    module V3
      module Store
        # One node as a picker reads it: what to show, what to sort by, and
        # whether asking again is worth a round trip.
        #
        # `has_children` is answered from the set the controller looked up once
        # for the whole page — an `exists?` per node is a query per node, and a
        # province list is thirty-one of them.
        class AdministrativeDivisionSerializer < V3::BaseSerializer
          typelize code: :string, name: :string, level: :string,
                   first_pinyin: :string, has_children: :boolean

          attributes :code, :name, :level, :first_pinyin

          attribute :has_children do |division|
            params[:parents_with_children]&.include?(division.id) || false
          end
        end
      end
    end
  end
end
