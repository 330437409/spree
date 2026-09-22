module Spree
  module PointProducts
    # A good that issues a membership card: the row points at the tier's own
    # group, and the membership plan issues the card
    # (docs/plans/6.1-membership-tiers-and-rights.md).
    class VipCard < Spree::PointProduct
      belongs_to :customer_group, class_name: 'Spree::CustomerGroup', optional: true

      validates :customer_group_id, presence: true
    end
  end
end
