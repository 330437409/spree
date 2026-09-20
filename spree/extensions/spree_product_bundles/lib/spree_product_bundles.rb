require 'spree_core'
require 'spree_product_bundles/engine'

# A product bundle — 套餐 — as this client sells it: **a composition and a
# discount, not a sellable variant**.
#
# A bundle is a row that says which variants, in what quantity, form a set, and
# what that set costs. It has no price of its own, no stock, no weight, no
# shipment and no reviews: the components are ordinary variants, so every one of
# those stays exactly where core already puts it, and a bundle simply inherits
# them. What the bundle owns is the composition, the price rule, and the
# availability verdict the client renders as one number — the scarcest
# component, expressed in bundles.
#
# Adding one to a cart writes the components as ordinary line items and tags
# them with a join row; the saving is an order-level discount the gem owns, not
# a promotion (see docs/plans/6.1-product-bundles.md).
module SpreeProductBundles
end
