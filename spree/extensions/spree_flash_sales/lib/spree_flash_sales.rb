require 'spree_core'
require 'spree_flash_sales/engine'

# A flash sale — 秒杀 — as this client runs it: **a window, a pool and a ticket
# that holds a unit**.
#
# The activity owns a pool in three scopes (all time, per day, per time slot),
# and the units a customer claims leave it through a ticket — a record that is
# neither a cart nor an order, invisible to the goods' own stock, released by
# expiry, cancellation or replacement. The pool is not stock: the shelf's own
# availability still has to allow the sale, and the smaller of the two decides
# (see docs/plans/6.1-flash-sales.md).
#
# The hold the ticket owns is deliberately generic — it knows a pool, an owner, a
# quantity and an expiry, and nothing about flash sales — because
# `6.1-group-buying.md` generalises it into core when it arrives.
module SpreeFlashSales
end
