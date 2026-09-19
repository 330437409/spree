module Spree
  module Api
    module V3
      module Store
        module Location
          # Which seller serves a coordinate.
          #
          # It is the client's first call and it is made before anyone has
          # signed in, which is why it opts out of the Store branch's login
          # gate — without that it would answer 401 to the only caller it has.
          class ResolveSellerController < Store::BaseController
            include Spree::Api::V3::HttpCaching

            allow_guest_storefront_access!

            COORDINATE_SYSTEMS = %w[gcj02 wgs84].freeze

            # GET /api/v3/store/location/resolve_seller?latitude=&longitude=&coordinate_system=
            def show
              return render_out_of_range_error unless coordinates_in_range?
              return unless stale?(etag: decision_etag, public: true)

              decision = Spree::SellerRouting::Locate.call(
                latitude: latitude, longitude: longitude, source: coordinate_system, store: current_store
              )

              render json: serializer_class.new(decision, params: serializer_params).to_h
            rescue Spree::ReverseGeocode::Error => error
              # The provider's own words travel: "此key每日调用量已达到上限" tells
              # an operator what to fix, and "geocoding failed" does not.
              render_error(
                code: ErrorHandler::ERROR_CODES[:reverse_geocode_unavailable],
                message: error.message,
                status: :service_unavailable
              )
            end

            private

            def latitude
              @latitude ||= coordinate(:latitude)
            end

            def longitude
              @longitude ||= coordinate(:longitude)
            end

            # A missing parameter and a value that is not a number are both 400s
            # in v3's own vocabulary, so they are raised rather than answered
            # here.
            def coordinate(name)
              value = params[name].presence || raise(ActionController::ParameterMissing.new(name))
              Float(value)
            end

            def coordinate_system
              requested = params[:coordinate_system].presence || COORDINATE_SYSTEMS.first

              unless COORDINATE_SYSTEMS.include?(requested)
                raise ArgumentError,
                      "unknown coordinate_system #{requested.inspect}, expected one of #{COORDINATE_SYSTEMS.join(', ')}"
              end

              requested
            end

            def coordinates_in_range?
              latitude.between?(-90, 90) && longitude.between?(-180, 180)
            end

            def render_out_of_range_error
              render_validation_error('latitude and longitude must be a point on Earth')
            end

            # A binding change must not be served stale from a CDN, so the
            # validator carries the routing configuration and not just the
            # coordinate: core's ETag machinery keys on a resource, and this
            # answer is a computation over several.
            def decision_etag
              [
                current_store.cache_key_with_version,
                latitude,
                longitude,
                coordinate_system,
                Spree::AdministrativeDivision.current_dataset_version,
                service_area_version
              ]
            end

            # The cheapest fact that moves whenever a binding does — including a
            # warehouse being deactivated or deleted, which is why deleted rows
            # are read too.
            def service_area_version
              Spree::StockLocation.with_deleted.maximum(:updated_at)&.to_i
            end

            def serializer_class
              Spree::Api::V3::Store::SellerDecisionSerializer
            end
          end
        end
      end
    end
  end
end
