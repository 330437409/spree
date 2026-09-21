module Spree
  module Ledger
    # Writes the negative counterpart of an entry, once.
    #
    # The reversal carries what the entry it undoes carries — the account, the
    # unit, and the source it came from — with the amount moving the other way,
    # so an audit reads the pair rather than a kind name it has to interpret.
    # A producer with a source of its own (the refund rather than the order it
    # refunds) writes the row through {Spree::Ledger.record!} with `reverses:`
    # instead.
    class Reverse
      prepend Spree::ServiceModule::Base

      # @param entry [Spree::LedgerEntry]
      # @param idempotency_key [String] supplied by the producer
      # @return [Spree::ServiceModule::Result] value is the reversing entry
      def call(entry:, idempotency_key:)
        Record.call(
          account: entry.account,
          kind: 'reversal',
          amount: entry.amount.abs,
          idempotency_key: idempotency_key,
          source: entry.source,
          reverses: entry,
          store: entry.store
        )
      end
    end
  end
end
