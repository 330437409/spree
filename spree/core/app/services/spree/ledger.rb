module Spree
  # The only door to `Spree::LedgerEntry`, and the one place a reversal's sign,
  # pairing and unit are decided.
  #
  # It records; the account performs. A redemption, a payout, a points spend
  # each move their own value in their own workflow and pass what happened in —
  # and where the movement *is* the balance, writing this row is how the
  # account applies it, so the balance the account reports is the one before
  # the movement (see {Spree::Ledger::Record#snapshot_for}). This module never
  # moves value, never holds a payee and never settles money
  # (docs/plans/6.1-ledger-primitive.md).
  #
  # An account is any record that answers two methods — the points account,
  # the distributor, the gift card:
  #
  #   def ledger_unit      # the unit its entries are written in
  #   def ledger_balance   # its balance as of now, which the primitive adds
  #                        # this movement to; nil where the instrument is
  #                        # authoritative, so no snapshot is written at all
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
    # entry the first call wrote. A key that is already taken by a *different*
    # movement is refused (`:key_reused`) rather than answered, because a key
    # too coarse to tell two movements apart would otherwise drop the second
    # one silently.
    #
    # @param account [Object] the record holding the balance, which must answer
    #   `ledger_unit` and `ledger_balance`
    # @param kind [String] the account's own word for this movement
    # @param amount [Numeric] signed: a spend, an expiry and a reversal are
    #   negative
    # @param idempotency_key [String] supplied by the producer, and specific
    #   enough to name this movement and no other
    # @param source [Object, nil] what caused it: an order, a refund, a campaign
    # @param unit [String, nil] the movement's unit, when it is not the
    #   account's own — a distributor earning in the order's currency; ignored
    #   for a reversal, which is always in the unit it reverses
    # @param occurred_at [Time, nil] defaults to now
    # @param reverses [Spree::LedgerEntry, nil] the entry this one undoes; its
    #   account and unit are taken from it and the amount's sign is forced to
    #   the opposite one
    # @param metadata [Hash, nil]
    # @param store [Spree::Store, nil] falls back to the account's own, and
    #   then to the current request's, which is why a job passes it
    # @return [Spree::ServiceModule::Result] value is the entry, or the row
    #   that holds a reused key
    # @raise [Spree::Ledger::NotAnAccount]
    def self.record!(**options)
      Record.call(**options)
    end

    # Writes the negative counterpart of an entry, once.
    #
    # The only place a reversal is written: the sign, the `reverses_entry_id`
    # and the unit are decided here rather than by each of the three families
    # inventing its own convention. The reversal carries what the entry it
    # undoes carries — its account, its unit, the source it came from and its
    # metadata — unless the caller names its own, which is what a refund does:
    # the refund is what caused the reversal, not the order it refunds.
    #
    # @param entry [Spree::LedgerEntry] what is being undone
    # @param idempotency_key [String] supplied by the producer
    # @param source [Object, nil] what caused the reversal; defaults to the
    #   reversed entry's source
    # @param occurred_at [Time, nil] defaults to now
    # @param metadata [Hash, nil] defaults to the reversed entry's metadata,
    #   so a clawback keeps the reason the customer was told
    # @return [Spree::ServiceModule::Result] value is the reversing entry
    def self.reverse!(entry, idempotency_key:, source: nil, occurred_at: nil, metadata: nil)
      Reverse.call(entry: entry, idempotency_key: idempotency_key,
                   source: source, occurred_at: occurred_at, metadata: metadata)
    end
  end
end
