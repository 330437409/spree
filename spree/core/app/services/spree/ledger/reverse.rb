module Spree
  module Ledger
    # Writes the negative counterpart of an entry, once.
    #
    # The reversal carries what the entry it undoes carries — the account, the
    # unit, the source, the metadata — with the amount moving the other way, so
    # an audit reads the pair rather than a kind name it has to interpret. A
    # caller with a source of its own (the refund rather than the order it
    # refunds) names it here; a caller that needs a whole movement of its own
    # writes it through {Spree::Ledger.record!} with `reverses:` instead.
    class Reverse
      prepend Spree::ServiceModule::Base

      # @param entry [Spree::LedgerEntry]
      # @param idempotency_key [String] supplied by the producer
      # @param source [Object, nil] what caused the reversal
      # @param occurred_at [Time, nil]
      # @param metadata [Hash, nil]
      # @return [Spree::ServiceModule::Result] value is the reversing entry
      def call(entry:, idempotency_key:, source: nil, occurred_at: nil, metadata: nil)
        Record.call(
          account: entry.account,
          kind: 'reversal',
          amount: entry.amount.abs,
          idempotency_key: idempotency_key,
          source: source || entry.source,
          occurred_at: occurred_at,
          metadata: metadata || entry.metadata,
          reverses: entry,
          store: entry.store
        )
      end
    end
  end
end
