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
  # The kinds of good a points shop can offer, each a subclass of
  # `Spree::PointProduct` that declares what a redemption issues. A registry
  # rather than a validated string, so a kind is a class a picker can list and
  # another gem can add one without editing this one.
  #
  # Filled by the engine after initialization, because a subclass may not exist
  # yet when this file loads.
  def self.point_product_types
    @point_product_types ||= []
  end
end
