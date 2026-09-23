module Spree
  module Api
    module V3
      module Store
        module Sites
          # The cities a site can be picked in — the client's location list,
          # which asks with no parameters and gets the places that have shops.
          class CitiesController < Store::BaseController
            include Spree::Api::V3::HttpCaching

            allow_guest_storefront_access!

            # GET /api/v3/store/sites/cities
            def index
              cities = Spree::SellerRouting::Sites.cities(store: current_store)

              render json: { data: cities.map { |division| serialize(division) } }
            end

            private

            def serialize(division)
              Spree::Api::V3::Store::RoutedDivisionSerializer.new(division, params: serializer_params).to_h
            end
          end
        end
      end
    end
  end
end
