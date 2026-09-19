require 'spree_core'
require 'spree_administrative_divisions'
require 'spree_service_areas/engine'
require 'spree_service_areas/routes'

# Which seller serves a coordinate — the answer a storefront needs before it can
# show a catalogue, a price or a delivery promise, read by the client's location
# first and bound to `Spree::Current.seller` for the rest of the request.
#
# The pieces are the service-area binding a warehouse carries (the columns are
# core's, on `spree_stock_locations`), the reverse geocoding that turns a pair
# into an administrative path, and the routing decision that matches them
# (see docs/plans/6.1-seller-service-area-routing.md).
module SpreeServiceAreas
end
