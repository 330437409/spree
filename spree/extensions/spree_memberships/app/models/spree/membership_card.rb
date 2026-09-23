module Spree
  # A membership bought, granted, held or given away — the instrument, before
  # anybody is entitled to anything.
  #
  # The buyer stays the buyer when the card is claimed: a card given away stays
  # in the giver's record as 已赠送 while the entitlement goes to whoever claimed
  # it, which is why the buyer and the activator are two columns and the term
  # hangs off the card rather than owning it
  # (docs/plans/6.1-membership-tiers-and-rights.md).
  #
  # Its status is the card's own — `dormant`, `active`, `recycled`, `expired` —
  # and what moves it is a workflow, never a state machine.
  class MembershipCard < Spree.base_class
    has_prefix_id :mcard

    include Spree::Metadata
    include Spree::SingleStoreResource
    include Spree::HasStatus

    has_status :dormant, :active, :recycled, :expired, default: :dormant

    SOURCES = %w[purchase grant].freeze

    belongs_to :customer, class_name: "::#{Spree.customer_class}"
    belongs_to :customer_group, class_name: 'Spree::CustomerGroup'
    # The tier it grants: one row keyed to the group, and a read rather than a
    # method so a collection can preload it.
    belongs_to :tier_setting, class_name: 'Spree::MembershipTierSetting',
               primary_key: :customer_group_id, foreign_key: :customer_group_id, inverse_of: nil, optional: true
    # The purchase that produced it; nil for a card an operator granted.
    belongs_to :scenario_order, class_name: 'Spree::ScenarioOrder', optional: true
    # The term it started, once it is activated. The card carries the link —
    # a column pointing back at it would be a cycle the two ends could disagree
    # about.
    belongs_to :membership, class_name: 'Spree::Membership', optional: true
    # Who activated it, when that is somebody other than the buyer: a claimed
    # gift is the case this exists for.
    belongs_to :activated_by_customer, class_name: "::#{Spree.customer_class}", optional: true

    validates :source, presence: true, inclusion: { in: SOURCES }
    validate :group_in_same_store

    scope :for_customer, ->(customer) { where(customer_id: customer&.id) }
    # What the wallet counts, and what 相赠 may act on.
    scope :giftable, -> { with_status(:dormant).where(giftable: true) }
    # Cards whose deadline to activate has passed. Read by the sweep.
    scope :overdue, -> { with_status(:dormant).where(activates_before: ..Time.current) }

    # @return [Boolean] whether the deadline to activate it has passed
    def overdue?
      dormant? && activates_before.present? && activates_before <= Time.current
    end

    private

    def group_in_same_store
      return if customer_group.nil? || store_id.nil?
      return if customer_group.store_id == store_id

      errors.add(:customer_group, :invalid)
    end
  end
end
