# frozen_string_literal: true

module Spree
  # One row for "the store owes this customer something": where it came from,
  # what it released, and when it stops being owed. A membership gift, a
  # coupon a draw handed over, a points lot, a welfare card, a referral
  # reward.
  #
  # The row carries the vocabulary every kind shares, and nothing else: no
  # amount, because a balance belongs to the thing owed; no expiry status,
  # because an expiry is a date to read rather than a fact a job writes. What
  # a kind means by consuming, whether its grants expire at all, and how it
  # builds its own idempotency key are the kind's business — the kinds are
  # registered classes (`Spree.grant_kinds`), and the only writer of this
  # table is `Spree::Grants` in the `spree_grants` gem
  # (docs/plans/6.1-grant-and-benefit-primitive.md).
  class Grant < Spree.base_class
    include Spree::SingleStoreResource
    include Spree::Metadata
    include Spree::HasStatus

    publishes_lifecycle_events

    acts_as_paranoid

    has_prefix_id :grant

    has_status :granted, :claimed, :consumed, :revoked, default: :granted

    # Null while the thing is owed to nobody yet: a campaign mints a coupon
    # holding before anyone draws it, and a transferred code sits unclaimed.
    belongs_to :customer, class_name: Spree.customer_class.to_s, optional: true

    # What caused the grant — an order, a right, a campaign — and what it
    # released, which belongs to the plan that issued it.
    belongs_to :source, polymorphic: true, optional: true
    belongs_to :issued, polymorphic: true, optional: true

    registers_subclasses_via { Spree.grant_kinds }

    validates :kind, presence: true
    # Taken across deleted rows too (`with_deleted`), and the unique index is
    # built the same way: the key means the debt was already recorded, so a
    # job that runs twice records nothing and a row removed by cleanup does not
    # hand the key back to be recorded again.
    validates :idempotency_key, presence: true,
                                uniqueness: { scope: [:kind, :store_id, *spree_base_uniqueness_scope],
                                              conditions: -> { with_deleted } }
    validates :granted_at, presence: true
    validate :expires_at_must_belong_to_a_kind_that_expires

    scope :expired, -> { where(expires_at: ..Time.current) }
    scope :expiring_before, ->(date) { where(expires_at: ..date) }
    scope :usable, lambda {
      with_status(:granted, :claimed).
        where(arel_table[:expires_at].eq(nil).or(arel_table[:expires_at].gt(Time.current)))
    }

    # The registered kind this row names, or nil while the gem that owns the
    # kind is not loaded — a row stays readable without it.
    #
    # @return [Class, nil]
    def kind_class
      self.class.find_by_api_type(kind)
    end

    # @return [Boolean] whether this grant is still owed and still in time
    def usable?
      (granted? || claimed?) && (expires_at.nil? || expires_at.future?)
    end

    private

    # A kind that never expires (`Spree::Grants::Kind#expires?`) has no use for
    # the column, and a date on its row would be a second answer to a question
    # its kind already answers.
    def expires_at_must_belong_to_a_kind_that_expires
      return if expires_at.blank? || kind_class.nil?
      return unless kind_class.respond_to?(:expires?) && !kind_class.expires?

      errors.add(:expires_at, :kind_does_not_expire,
                 message: Spree.t('errors.messages.grant_kind_does_not_expire'))
    end
  end
end
