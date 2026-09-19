module Spree
  module Api
    module V3
      module Store
        # The sites a customer can shop at, and the record of the one a request
        # belongs to.
        #
        # Two reads of one resource: `index` answers where there are sites at
        # all, from a coordinate, and `show` answers for the site the request was
        # scoped to. Both are public — a customer reads them before they have an
        # account, and before they know which shop to ask about.
        class SitesController < Store::BaseController
          include Spree::Api::V3::HttpCaching
          include CoordinateLookups
          include SiteScope

          allow_guest_storefront_access!

          # GET /api/v3/store/sites?latitude=&longitude=
          def index
            return render_out_of_range_error unless coordinates_in_range?

            sellers = Spree::SellerRouting::Sites.around(
              latitude: latitude, longitude: longitude, store: current_store
            )

            render json: {
              data: sellers.map { |seller| Spree.api.seller_serializer.new(seller, params: serializer_params).to_h }
            }
          end

          # GET /api/v3/store/site
          def show
            return render_missing_site if current_seller.nil?
            return unless cache_resource(current_seller)

            render json: serializer_class.new(current_seller, params: serializer_params).to_h
          end

          private

          def serializer_class
            Spree::Api::V3::Store::SiteSerializer
          end
        end
      end
    end
  end
end
