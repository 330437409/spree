require 'spree_core'
require 'spree_grants'
require 'spree_points/engine'

# One ledger, two balances: 积分 (points) are earned on an order and spent in a
# shop; 成长值 (growth value) is earned the same way and never spent, because it
# is what moves a customer up the membership ladder.
#
# Neither balance is a table of this gem's: a lot is a kind of the shared grant
# row (`Spree::Grant`) and every movement is a row of the shared ledger
# (`Spree::LedgerEntry`). What this gem owns is the account, the lot's own
# side table, the allocation audit trail and the service other extensions earn
# through (docs/plans/6.1-points-and-growth-value.md).
module SpreePoints
end
