module Spree
  module StockLocations
    # Turns a warehouse's address into the coordinates a buyer's location is
    # compared against.
    #
    # Forward, as opposed to the reverse geocoding a storefront does when it
    # looks up which seller serves a point: this one goes address → coordinates
    # and happens once per address change, not once per request. The pair is
    # stored in GCJ-02 whatever the lookup service answers in, because that is
    # what the polygon tests and the distance read.
    class ForwardGeocodeJob < Spree::BaseJob
      queue_as Spree.queues.addresses

      GeocodeError = Class.new(StandardError)

      def perform(stock_location_id)
        stock_location = Spree::StockLocation.find(stock_location_id)

        # `#address` answers a blank record whatever the columns hold, and a
        # blank address reads as configured — every caller of it guards first,
        # and a job called directly rather than enqueued is no exception. A
        # location with nothing to geocode is not a failure, so it is left as
        # it stands rather than marked one.
        return unless stock_location.postable?

        latitude, longitude = coordinates_for(stock_location)

        if latitude.present?
          stock_location.update_columns(
            latitude: latitude,
            longitude: longitude,
            geocoded_at: Time.current,
            geocode_provider: Geocoder.config.lookup.to_s,
            geocode_status: 'success',
            updated_at: Time.current
          )
        else
          mark_failed(stock_location)
        end
      end

      private

      # The lookup is somebody else's network, and this job runs on every
      # address change: a refusal, a timeout, or a connection something else
      # has closed is recorded on the row rather than raised, because a
      # warehouse whose geocoding fails must not take the queue down with it —
      # and the status is what tells an operator to look.
      #
      # @return [Array(Float, Float), nil] the pair in GCJ-02, nil when the
      #   lookup answered nothing or could not be made
      def coordinates_for(stock_location)
        address = stock_location.address
        coordinates = Geocoder.coordinates(address.geocoder_address, country: address.country_iso3)
        return nil if coordinates.blank?

        Spree::CoordinateNormalizer.normalize(
          latitude: coordinates[0],
          longitude: coordinates[1],
          source: Spree::CoordinateNormalizer.source_for_lookup(Geocoder.config.lookup)
        )
      rescue StandardError => error
        Rails.error.report(error, handled: true, context: { stock_location_id: stock_location.id }, source: 'spree.core')

        nil
      end

      def mark_failed(stock_location)
        # The geocoder's own reason is only in the log, so the row carries the
        # part an operator can act on: this address produced no coordinates,
        # and it was tried.
        stock_location.update_columns(
          geocode_status: 'failed',
          geocode_provider: Geocoder.config.lookup.to_s,
          updated_at: Time.current
        )

        Rails.error.report(
          GeocodeError.new("Cannot geocode stock location ID: #{stock_location.id}"),
          handled: false,
          context: { stock_location_id: stock_location.id },
          source: 'spree.core'
        )
      end
    end
  end
end
