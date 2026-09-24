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
    # The tier this term holds: one row keyed to the group, and a read rather
    # than a method so a collection can preload it.
    belongs_to :tier_setting, class_name: 'Spree::MembershipTierSetting',
               primary_key: :customer_group_id, foreign_key: :customer_group_id, inverse_of: nil, optional: true
    # The instrument it started from. The card carries the key, so this is a
    # read, not a second place the link can be set.
    has_one :card, class_name: 'Spree::MembershipCard', inverse_of: :membership, dependent: nil

    validates :customer_group_id, presence: true
    validate :ends_after_starts
    validate :one_live_term_per_tier, on: :create

    scope :live, -> { where(status: LIVE_STATUSES) }
    scope :for_customer, ->(customer) { where(customer_id: customer&.id) }
    scope :on, ->(customer_group_id) { where(customer_group_id: customer_group_id) }
    # Holding a tier right now: started, and not yet ended. The same question
    # #running? asks in Ruby.
    scope :running, -> { with_status(:active, :past_due).where(starts_at: ..Time.current) }
    # What the sweep has something to say about: a term whose window opened, and
    # one whose window closed. A term still inside its window is neither, which
    # is what keeps an hourly pass off every live term a store has.
    scope :due, ->(now = Time.current) {
      with_status(:pending).where(starts_at: ..now).
        or(with_status(:active, :past_due).where(ends_at: ..now))
    }

    # What a term of this tier would find waiting: the live terms the customer
    # already holds, and which of them a new one is subject to.
    #
    # Activating a card writes the same tier's live term longer, waits behind
    # another tier's, or starts now — and a customer is warned about that wait
    # *before* they pay for the card that will be subject to it. Both ask this
    # question of these rows, so the wait the customer is told about and the
    # wait they get are one computation rather than two that agree today.
    #
    # @param customer [Object]
    # @param customer_group_id [String] the tier the incoming term is for
    # @return [Hash] `:same_tier` — the live term of this tier the incoming one
    #   extends instead of waiting; `:waits_behind` — the live term it queues
    #   behind, which is the last of them to end, because a customer who bought
    #   two tiers ahead waits for both; `:blocked_by` — a live term held with no
    #   end, which is a person's decision rather than a clock's and refuses the
    #   incoming one outright. The last two are mutually exclusive, and both are
    #   nil when nothing is in the way.
    def self.arrival_for(customer:, customer_group_id:)
      # Loaded once and answered in Ruby: all three questions are asked of the
      # same handful of rows — one live term per tier at most — and asking the
      # database for each would be three round trips for one answer.
      held = live.for_customer(customer).to_a
      waits_behind = held.select(&:ends_at).max_by(&:ends_at)

      {
        same_tier: held.find { |term| term.customer_group_id == customer_group_id },
        waits_behind: waits_behind,
        blocked_by: waits_behind.nil? ? held.first : nil
      }
    end

    # Whether this term is holding its tier right now — started, and not ended.
    # The same question the `running` scope asks, in Ruby.
    #
    # @return [Boolean]
    def running?
      status.in?(%w[active past_due]) && starts_at.present? && starts_at <= Time.current
    end

    # @return [Boolean] whether this term still exists as far as the ladder is
    #   concerned: a pending one is live without holding anything yet
    def live?
      LIVE_STATUSES.include?(status)
    end

    private

    def ends_after_starts
      return if starts_at.blank? || ends_at.blank? || ends_at >= starts_at

      errors.add(:ends_at, :before_start, message: Spree.t('memberships.errors.ends_before_start'))
    end

    # The index is the last word; this is the same rule said where a caller can
    # read it, so a second live term is a validation failure rather than a raw
    # RecordNotUnique out of whatever service wrote it.
    def one_live_term_per_tier
      return if customer_id.blank? || customer_group_id.blank?
      return unless status.in?(LIVE_STATUSES)
      return unless self.class.live.where(customer_id: customer_id).on(customer_group_id).exists?

      errors.add(:base, :live_term_exists, message: Spree.t('memberships.errors.live_term_exists'))
    end
  end
end
