module Spree
  # A period a named customer holds a tier for — the entitlement, once a card
  # has been activated.
  #
  # `pending` is a term whose window has not opened yet: a customer who buys a
  # new tier while their current one still runs holds both, and their benefits
  # change when the old term ends (docs/plans/6.1-membership-tiers-and-rights.md).
  # `past_due` is the grace window behind it, ported from `spree_crm`.
  #
  # A live term and the tier's group are the same fact seen twice: the status
  # that ends a term leaves the group in the same transaction, because member
  # pricing reads the group.
  class Membership < Spree.base_class
    has_prefix_id :memb

    include Spree::Metadata
    include Spree::SingleStoreResource
    include Spree::HasStatus

    has_status :pending, :active, :past_due, :cancelled, :expired, default: :pending

    # The statuses a term still holds its tier for. Anything else is history.
    LIVE_STATUSES = %w[pending active past_due].freeze

    belongs_to :customer, class_name: "::#{Spree.customer_class}"
    belongs_to :customer_group, class_name: 'Spree::CustomerGroup'
    # The instrument it started from. The card carries the key, so this is a
    # read, not a second place the link can be set.
    has_one :card, class_name: 'Spree::MembershipCard', inverse_of: :membership, dependent: nil

    validates :customer_group_id, presence: true
    validate :ends_after_starts

    scope :live, -> { where(status: LIVE_STATUSES) }
    scope :for_customer, ->(customer) { where(customer_id: customer&.id) }
    # Terms the sweep has to look at: live, and past the instant their window
    # closed. A pending term is due when its start arrives, which is the other
    # half of the same question.
    scope :due, -> { live.where(ends_at: ..Time.current) }
    scope :awaiting_start, -> { with_status(:pending).where(starts_at: ..Time.current) }
    # Holding a tier right now: started, and not yet ended.
    scope :running, -> { with_status(:active, :past_due).where(starts_at: ..Time.current) }
    scope :on, ->(customer_group_id) { where(customer_group_id: customer_group_id) }

    # @return [Spree::MembershipTierSetting, nil] the tier this term holds
    def tier_setting
      Spree::MembershipTierSetting.find_by(customer_group_id: customer_group_id)
    end

    # Whether this term is still holding its tier — started, and not ended.
    #
    # @return [Boolean]
    def running?
      active? || past_due?
    end

    # @return [Boolean] whether this term still exists as far as the ladder is
    #   concerned: a pending one is live without holding anything yet
    def live?
      LIVE_STATUSES.include?(status)
    end

    private

    def ends_after_starts
      return if starts_at.blank? || ends_at.blank? || ends_at >= starts_at

      errors.add(:ends_at, :before_start, message: 'must be on or after the start')
    end
  end
end
