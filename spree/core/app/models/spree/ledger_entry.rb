# frozen_string_literal: true

module Spree
  # One balance movement: the account it moved, the unit, the signed amount,
  # where the balance stood afterwards, and the key that makes the producer's
  # retry harmless.
  #
  # Append-only by construction. A wrong entry is reversed — a pairing row with
  # a negative amount pointing at it — never updated and never deleted, so
  # there is no `status` here, no soft delete, and `readonly?` refuses every
  # write to a persisted row. Three families that each invented their own
  # reversal convention is the problem this row exists to remove
  # (docs/plans/6.1-ledger-primitive.md).
  class LedgerEntry < Spree.base_class
    include Spree::SingleStoreResource
    include Spree::Metadata

    publishes_lifecycle_events only: [:create]

    has_prefix_id :ledger

    # What holds the balance — a points account, a distributor, a gift card.
    # Polymorphic, so this row knows nothing about what the account means; the
    # contract it must answer is {Spree::Ledger}'s.
    belongs_to :account, polymorphic: true

    # What caused the movement: an order, a refund, a campaign.
    belongs_to :source, polymorphic: true, optional: true

    # What this entry undoes. The pair is the two rows pointing at each other,
    # which is what makes a refunded order legible rather than a kind name to
    # interpret.
    belongs_to :reverses_entry, class_name: 'Spree::LedgerEntry', optional: true

    validates :kind, presence: true
    validates :unit, presence: true
    validates :occurred_at, presence: true
    validates :idempotency_key, presence: true,
                                uniqueness: { scope: [:account_type, :account_id] }
    # A reversal is the negative counterpart of what it reverses, in the same
    # unit: the sign is the convention this row carries for all three families.
    validate :reversal_must_undo_the_entry_it_points_at

    scope :for_account, ->(account) { where(account: account) }
    scope :in_unit, ->(unit) { where(unit: unit.to_s) }
    scope :reversals, -> { where.not(reverses_entry_id: nil) }
    scope :chronological, -> { order(:occurred_at, :id) }

    # A balance is a sum filtered by unit. `balance_after` exists so the common
    # read never has to sum.
    #
    # @param unit [String]
    # @return [BigDecimal]
    def self.balance_for(account, unit:)
      for_account(account).in_unit(unit).sum(:amount)
    end

    # An entry is written once and read forever: correcting one is a reversal
    # row, which is what keeps a balance explainable.
    #
    # @return [Boolean]
    def readonly?
      persisted?
    end

    private

    def reversal_must_undo_the_entry_it_points_at
      return if reverses_entry.nil?

      if account_type != reverses_entry.account_type || account_id != reverses_entry.account_id
        errors.add(:account, :ledger_reversal_account_mismatch,
                   message: Spree.t('errors.messages.ledger_reversal_account_mismatch'))
      end

      if unit != reverses_entry.unit
        errors.add(:unit, :ledger_reversal_unit_mismatch,
                   message: Spree.t('errors.messages.ledger_reversal_unit_mismatch'))
      end

      return if amount.nil? || amount.zero? || reverses_entry.amount.nil? || reverses_entry.amount.zero?
      return if amount.negative? != reverses_entry.amount.negative?

      errors.add(:amount, :ledger_reversal_sign_mismatch,
                 message: Spree.t('errors.messages.ledger_reversal_sign_mismatch'))
    end
  end
end
