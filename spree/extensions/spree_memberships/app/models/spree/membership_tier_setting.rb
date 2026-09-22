module Spree
  # What makes a `Spree::CustomerGroup` a tier: its rung on the ladder, what
  # qualifies for it, and how long a term of it lasts.
  #
  # The row has no name and no member list — the group it hangs from has both —
  # which is what keeps it from being a second audience model. Its existence is
  # also how a loyalty tier is told from the wholesale-buyer group that shares
  # the same table (docs/plans/6.1-membership-tiers-and-rights.md).
  class MembershipTierSetting < Spree.base_class
    include Spree::Metadata

    acts_as_paranoid

    belongs_to :customer_group, class_name: 'Spree::CustomerGroup', touch: true

    # The tier reaches the store through its group: a second tenancy column
    # would be a second thing to keep in step.
    delegate :store, to: :customer_group, allow_nil: true
    delegate :name, :customers, to: :customer_group, allow_nil: true

    validates :rank, presence: true, numericality: { only_integer: true }
    # Among live rows only, matching the index: a retired settings row is
    # history, and a fresh one for the same group is saved after it is retired.
    validates :customer_group_id, uniqueness: { conditions: -> { where(deleted_at: nil) } }
    validates :validity_days, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :threshold, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

    scope :ordered, -> { order(:rank, :id) }
    scope :for_store, ->(store) { joins(:customer_group).where(spree_customer_groups: { store_id: store&.id }) }

    # What a customer at this tier has spent to be here, or nil when the tier is
    # sold rather than earned.
    #
    # @return [BigDecimal, nil]
    def qualifies?(amount)
      threshold.present? && amount.to_d >= threshold
    end
  end
end
