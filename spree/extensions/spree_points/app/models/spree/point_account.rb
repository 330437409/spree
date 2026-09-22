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
    validates_store_uniqueness :kind, scope: [:customer_id]
    validates :lifetime_earned, numericality: { only_integer: true }

    # The row for a balance, written on first use.
    #
    # Looked up first, and a lost race answered with the row that won: the
    # first earn for a new customer can arrive twice at once, and the unique
    # index would otherwise raise inside the loser's own transaction. The
    # insert takes a savepoint for the same reason the ledger's does — a
    # caller's transaction must survive the collision.
    #
    # @param store [Spree::Store]
    # @param customer [Object]
    # @param kind [String]
    # @return [Spree::PointAccount]
    def self.for(store:, customer:, kind:)
      kind = kind.to_s
      existing = find_by(store: store, customer: customer, kind: kind)
      return existing if existing

      transaction(requires_new: true) { create!(store: store, customer: customer, kind: kind) }
    rescue ActiveRecord::RecordNotUnique
      find_by!(store: store, customer: customer, kind: kind)
    end

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

    # What the balance read asks in one query rather than two: how much of the
    # balance is about to lapse, and the date the next of it does.
    #
    # @return [Array(Integer, Time, nil)]
    def expiring_summary(within: nil)
      return [0, nil] if new_record?

      lots = expiring_lots(within: within)
      total, soonest = lots.pick(lots.arel_table[:remaining].sum,
                                 Spree::Grant.arel_table[:expires_at].minimum)

      # `pick` hands back the raw column for an aggregate, so the date is cast
      # here rather than arriving as the driver's string.
      [total.to_i, soonest && Spree::Grant.type_for_attribute(:expires_at).cast(soonest)]
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
      (Spree::Current.store&.preferred_points_expiry_warning_days || 30).days
    end
  end
end
