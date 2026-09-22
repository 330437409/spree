module Spree
  # One balance of one customer in one store: 积分, earned and spent, or
  # 成长值, earned and never spent because it is what moves the membership
  # ladder.
  #
  # The row carries no balance. It exists for the lock a spend takes and for
  # `lifetime_earned`; the balance is the sum of the usable lots' `remaining`,
  # which is what lets an expiry be a date fact with no job and no writer
  # (docs/plans/6.1-points-and-growth-value.md).
  class PointAccount < Spree.base_class
    include Spree::SingleStoreResource
    include Spree::Metadata

    # The two balances. A third — 酒神值 — is the same idea again and is
    # deliberately left unbuilt: the schema is not closed to it and nothing
    # registers it.
    KINDS = %w[points growth_value].freeze
    POINTS = 'points'.freeze
    GROWTH_VALUE = 'growth_value'.freeze

    publishes_lifecycle_events

    has_prefix_id :ptacct

    belongs_to :customer, class_name: Spree.customer_class.to_s

    has_many :point_grants, class_name: 'Spree::PointGrant', dependent: :destroy_async,
                            inverse_of: :account
    has_many :ledger_entries, class_name: 'Spree::LedgerEntry', as: :account,
                              dependent: :restrict_with_error

    validates :kind, presence: true, inclusion: { in: KINDS }
    validates :kind, uniqueness: { scope: [:store_id, :customer_id, *spree_base_uniqueness_scope] }
    validates :lifetime_earned, numericality: { only_integer: true }

    scope :points, -> { where(kind: POINTS) }
    scope :growth_value, -> { where(kind: GROWTH_VALUE) }

    # @return [Boolean] whether this balance is the spendable one
    def points?
      kind == POINTS
    end

    # The ledger's account contract: the unit a movement is written in is the
    # balance it moves, so a row says which balance it changed without a
    # second column.
    #
    # @return [String]
    def ledger_unit
      kind
    end

    # The ledger's account contract: the balance as of now, before the movement
    # being recorded — which the primitive then adds. A lot is granted and
    # counted here, so nothing else has applied the movement yet.
    #
    # @return [Integer]
    def ledger_balance
      balance
    end

    # The sum of the usable lots' `remaining`. Nothing stores it: an expiry is
    # a date the query reads.
    #
    # @return [Integer]
    def balance
      return 0 if new_record?

      usable_lots.sum(:remaining)
    end

    # @return [Integer] what is left, and about to lapse, inside the window
    def expiring_total(within: nil)
      return 0 if new_record?

      expiring_lots(within: within).sum(:remaining)
    end

    # @return [Time, nil] the date the next of them lapses
    def next_expiry(within: nil)
      return nil if new_record?

      expiring_lots(within: within).minimum('spree_grants.expires_at')
    end

    # @return [ActiveRecord::Relation] the lots a spend may draw on
    def usable_lots
      point_grants.joins(:grant).merge(Spree::Grant.usable)
    end

    def expiring_lots(within: nil)
      window = within || Spree::PointAccount.expiry_warning_window
      usable_lots.merge(Spree::Grant.expiring_before(window.from_now))
    end

    # How far ahead the balance read warns about an expiry.
    #
    # @return [Time]
    def self.expiry_warning_window
      days = Spree::Current.store&.preferred_points_expiry_warning_days.to_i

      days.positive? ? days.days : 30.days
    end
  end
end
