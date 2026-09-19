module Spree
  module Api
    module V3
      module Store
        module ServiceAreas
          # Whether a division is already claimed.
          #
          # The seller-join form asks it before offering an area, so that a
          # prospective seller is told the node is taken rather than filling in a
          # form that will be refused at save. The rule is the binding's own —
          # one active warehouse per node — read here rather than restated.
          class TakenController < Store::BaseController
            allow_guest_storefront_access!

            # GET /api/v3/store/service_areas/taken?division_code=
            def show
              code = params[:division_code].presence || raise(ActionController::ParameterMissing.new(:division_code))
              division = Spree::AdministrativeDivision.find_by(code: code)

              # A code this release does not carry is not taken by anyone, which
              # is the truth: nothing holds a node that does not exist.
              render json: { taken: division.present? && held?(division) }
            end

            private

            # Deliberately not scoped to the store: the partial unique index and
            # the model's own validation both read every warehouse, so a
            # store-scoped answer here would offer an area the save then refuses.
            def held?(division)
              Spree::StockLocation.active.where(administrative_division_id: division.id).exists?
            end
          end
        end
      end
    end
  end
end
