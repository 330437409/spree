require 'spree_core'
require 'spree_administrative_divisions/engine'
require 'spree_administrative_divisions/routes'

# The Chinese administrative tree as reference data: five levels deep
# (country → province → city → district → township), imported from a versioned
# dataset rather than edited, and read by everything that needs to name a
# division — the seller service-area bindings, the address and seller-join
# pickers, and the regional pricing work
# (see docs/plans/6.1-administrative-division-gem.md).
module SpreeAdministrativeDivisions
end
