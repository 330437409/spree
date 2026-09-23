module Spree
  module Api
    module V3
      module Store
        module Site
          # Where this site delivers — the divisions its warehouses are bound to.
          #
          # It is the seller's own bindings read back rather than a computation,
          # and the client uses it as the address form's third tier: an address
          # is checked against the shop it is being given to.
          class CoverageController < Store::BaseController
            include SiteScope

            allow_guest_storefront_access!

            # GET /api/v3/store/site/coverage
            def show
              return render_missing_site if current_seller.nil?

              render json: { data: divisions.map { |division| serialize(division) } }
            end

            private

            def divisions
              Spree::AdministrativeDivision.
                where(id: bound_division_ids).
                order(:depth, :first_pinyin)
            end

            def bound_division_ids
              current_seller.stock_locations.
                active.
                where.not(administrative_division_id: nil).
                select(:administrative_division_id)
            end

            def serialize(division)
              Spree::Api::V3::Store::RoutedDivisionSerializer.new(division, params: serializer_params).to_h
            end
          end
        end
      end
    end
  end
end
