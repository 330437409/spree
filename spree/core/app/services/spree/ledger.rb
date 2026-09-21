module Spree
  # The only door to `Spree::LedgerEntry`, and the one place a reversal's sign,
  # pairing and unit are decided.
  #
  # It records; the account performs. A points spend does its own locking, a
  # card's redemption is the card's own workflow, a distributor's earning comes
  # out of the commission engine — each of them moves the value and passes what
  # happened in. This module never moves value, never holds a payee and never
  # settles money (docs/plans/6.1-ledger-primitive.md).
  #
  # An account is any record that answers {#ledger_unit} and {#ledger_balance}:
  #
  #   # the points account, the distributor, the gift card
  #   def ledger_unit      # the unit its entries are written in
  #   def ledger_balance   # its balance for the snapshot, or nil where the
  #                        # instrument is authoritative — a gift card's own
  #                        # amount_used is the balance, so a snapshot here
  #                        # would be the second source of truth its plan forbids
  #   end
  #
  # There is no registry and no enum: `kind` is the account's own vocabulary,
  # and the points plan's reasons are operator data rather than a closed set
  # this primitive could validate.
  module Ledger
    # Raised when a caller names an account that answers neither contract
    # method — a row nobody could read a balance from is worse than a loud
    # refusal.
    class NotAnAccount < StandardError; end

    # Writes one entry, once.
    #
    # Idempotent by the producer's own key: the retry of a webhook, a job that
    # ran twice and a request somebody submitted twice all answer with the
    # entry the first call wrote.
    #
    # @param account [Object] the record holding the balance, which must answer
    #   `ledger_unit` and `ledger_balance`
    # @param kind [String] the account's own word for this movement
    # @param amount [Numeric] signed: a spend, an expiry and a reversal are
    #   negative
    # @param idempotency_key [String] supplied by the producer
    # @param source [Object, nil] what caused it: an order, a refund, a campaign
    # @param occurred_at [Time, nil] defaults to now
    # @param reverses [Spree::LedgerEntry, nil] the entry this one undoes; its
    #   unit and account are taken from it and the amount's sign is forced to
    #   the opposite one
    # @param metadata [Hash, nil]
    # @param store [Spree::Store, nil] falls back to the current request's,
    #   which is why a job passes it
    # @return [Spree::ServiceModule::Result] value is the entry
    # @raise [Spree::Ledger::NotAnAccount]
    def self.record!(**options)
      Record.call(**options)
    end

    # Writes the negative counterpart of an entry, once.
    #
    # The only place a reversal is written: the sign, the `reverses_entry_id`
    # and the unit are decided here rather than by each of the three families
    # inventing its own convention.
    #
    # @param entry [Spree::LedgerEntry] what is being undone
    # @param idempotency_key [String] supplied by the producer
    # @return [Spree::ServiceModule::Result] value is the reversing entry
    def self.reverse!(entry, idempotency_key:)
      Reverse.call(entry: entry, idempotency_key: idempotency_key)
    end
  end
end
