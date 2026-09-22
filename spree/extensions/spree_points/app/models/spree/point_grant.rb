module Spree
  # A lot: the side table of one core `Spree::Grant` row.
  #
  # The primitive owns who is owed, what caused it, when it was granted, when
  # it lapses and whether it still is; this table owns what only a lot has —
  # how much of it is left, which balance it belongs to, and why the operator
  # granted it. `remaining` is written by the ledger service and by nothing
  # else (docs/plans/6.1-points-and-growth-value.md).
  class PointGrant < Spree.base_class
    belongs_to :grant, class_name: 'Spree::Grant'
    belongs_to :account, class_name: 'Spree::PointAccount', inverse_of: :point_grants
    belongs_to :reason, class_name: 'Spree::PointReason', optional: true

    has_many :point_allocations, class_name: 'Spree::PointAllocation',
                                 dependent: :destroy_async, inverse_of: :point_grant

    has_prefix_id :ptlot

    validates :amount, numericality: { only_integer: true, greater_than: 0 }
    validates :remaining, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :grant_id, uniqueness: true
    validate :remaining_must_fit_inside_the_lot

    # Soonest-expiry-first, because a lot that expires tomorrow is worth more
    # to the customer today than one that never expires. `NULLS LAST` is not
    # portable — MySQL has no such clause and sorts nulls first — so the
    # placement is an ordering column every engine agrees on.
    scope :soonest_first, lambda {
      expires_at = Spree::Grant.arel_table[:expires_at]
      order(Arel::Nodes::Case.new.when(expires_at.eq(nil)).then(1).else(0), expires_at.asc, :id)
    }

    private

    def remaining_must_fit_inside_the_lot
      return if amount.nil? || remaining.nil? || remaining <= amount

      errors.add(:remaining, :point_lot_overdrawn,
                 message: Spree.t('errors.messages.point_lot_overdrawn'))
    end
  end
end
