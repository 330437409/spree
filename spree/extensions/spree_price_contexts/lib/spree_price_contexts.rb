require 'spree_core'
require 'spree_price_contexts/engine'
require 'spree_price_contexts/contexts'

# The price contexts a storefront asks in — 区域, 现场推广 and 线下 — as the
# client names them, and the reads that answer them.
#
# A context is a channel: the client sends its code in `X-Spree-Channel`, core's
# own channel resolution writes it into `Spree::Current.channel`, and the
# catalogue, the price and the delivery promise are then answered for it — one
# context by construction rather than three that have to be kept in step. A
# seller's own price is its offer variant's base price, so no price row carries
# a seller.
#
# Nothing here resolves a seller: `spree_service_areas` owns that and this gem
# reads its answer (docs/plans/6.1-seller-scoped-pricing.md).
module SpreePriceContexts
end
