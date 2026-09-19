module Spree
  module Api
    module V3
      module Store
        # What every coordinate-taking public read needs: strict input, and a
        # limit on how often one client can spend a provider call through it.
        #
        # They are one concern because they are one decision — this endpoint is
        # public and costs money per miss — and the reads that take a coordinate
        # are exactly the reads that pay for it. The reverse-geocode cache is
        # still the primary cost control underneath.
        module CoordinateLookups
          extend ActiveSupport::Concern

          COORDINATE_SYSTEMS = %w[gcj02 wgs84].freeze
          RATE_LIMIT_CALLS = 60
          RATE_LIMIT_WINDOW = 1.minute

          included do
            before_action :enforce_coordinate_rate_limit
          end

          # @return [Float]
          def latitude
            @latitude ||= coordinate(:latitude)
          end

          # @return [Float]
          def longitude
            @longitude ||= coordinate(:longitude)
          end

          # @return [String] the system the pair arrives in, refused when unknown
          def coordinate_system
            requested = params[:coordinate_system].presence || COORDINATE_SYSTEMS.first

            unless COORDINATE_SYSTEMS.include?(requested)
              raise ArgumentError,
                    "unknown coordinate_system #{requested.inspect}, expected one of #{COORDINATE_SYSTEMS.join(', ')}"
            end

            requested
          end

          # @return [Boolean]
          def coordinates_in_range?
            latitude.between?(-90, 90) && longitude.between?(-180, 180)
          end

          def render_out_of_range_error
            render_validation_error('latitude and longitude must be a point on Earth')
          end

          private

          # A missing parameter and a value that is not a number are both 400s in
          # v3's own vocabulary, so they are raised rather than answered here.
          def coordinate(name)
            value = params[name].presence || raise(ActionController::ParameterMissing.new(name))
            Float(value)
          end

          def enforce_coordinate_rate_limit
            return if Spree::SellerRouting::RateLimit.allow?(
              key: "spree_seller_routing/#{current_store.id}/#{request.remote_ip}",
              limit: RATE_LIMIT_CALLS,
              window: RATE_LIMIT_WINDOW
            )

            render_error(
              code: ErrorHandler::ERROR_CODES[:rate_limit_exceeded],
              message: 'Too many location lookups from this client. Try again in a minute.',
              status: :too_many_requests
            )
          end
        end
      end
    end
  end
end
