module Spree
  module Api
    module V3
      module Store
        module Location
          # Does this shop serve this point?
          #
          # The client asks it twice on the address form: with the warehouse the
          # customer is buying from (`address/checkShop`), and about the seller
          # itself (`address/checkSpecial`). The campaign tier stays excluded —
          # its check answers from the seller, which is a superset of any zone it
          # would have defined (Decision 21).
          #
          # The answer is a verdict rather than a record: the client reads a
          # boolean and decides what to say.
          class CoverageController < Store::BaseController
            include CoordinateLookups

            allow_guest_storefront_access!

            # GET /api/v3/store/location/coverage?latitude=&longitude=&warehouse_id=
            def show
              return render_out_of_range_error unless coordinates_in_range?

              resolution = Spree::ReverseGeocode::Resolve.call(
                latitude: latitude, longitude: longitude, source: coordinate_system, store: current_store
              )

              render json: { serves: serves?(resolution.path) }
            rescue Spree::ReverseGeocode::Error => error
              render_error(
                code: ErrorHandler::ERROR_CODES[:reverse_geocode_unavailable],
                message: error.message,
                status: :service_unavailable
              )
            end

            private

            def serves?(path)
              candidate_locations.any? do |location|
                Spree::SellerRouting::Coverage.covers?(
                  location: location, path: path, latitude: latitude, longitude: longitude
                )
              end
            end

            # A named warehouse is the whole question; without one it is the
            # seller's, which is every warehouse they have. A request with
            # neither serves nothing rather than guessing which shop was meant.
            def candidate_locations
              warehouse = named_warehouse
              return [warehouse] if warehouse
              return current_seller.stock_locations.active if current_seller

              []
            end

            # Read through the owner, never the class: a warehouse id from
            # another seller or another store is a 404, not someone else's shop.
            def named_warehouse
              id = params[:warehouse_id].presence
              return nil if id.blank?

              scope = current_seller ? current_seller.stock_locations : current_store.stock_locations
              scope.find_by_prefix_id!(id)
            end
          end
        end
      end
    end
  end
end
