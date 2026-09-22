module Spree
  module Ledger
    # Writes one entry, once.
    #
    # See {Spree::Ledger.record!} for the keywords. Nothing here moves value:
    # a caller that has already moved it — a redemption, a spend, a commission
    # calculation — passes what happened in.
    class Record
      prepend Spree::ServiceModule::Base

      # @return [Spree::ServiceModule::Result] value is the entry
      def call(account:, kind:, amount:, idempotency_key:, source: nil, occurred_at: nil,
               reverses: nil, metadata: nil, store: nil)
        assert_account!(account)

        return failure(nil, :key_missing) if idempotency_key.blank?

        # The account's own store, because that is what the balance belongs to;
        # the request's only when the account carries none.
        store ||= account.try(:store) || Spree::Current.store

        existing = find_existing(account, idempotency_key)
        return success(existing) if existing

        signed = signed_amount(amount, reverses)

        entry = Spree::LedgerEntry.new(
          store: store,
          account: account,
          kind: kind,
          unit: unit_for(account, reverses),
          amount: signed,
          balance_after: snapshot_for(account, signed),
          reverses_entry: reverses,
          idempotency_key: idempotency_key,
          source: source,
          occurred_at: occurred_at || Time.current,
          metadata: metadata || {}
        )

        saved = begin
          entry.save
        rescue ActiveRecord::RecordNotUnique
          # The key was taken between the lookup and the insert — the retry the
          # key exists for, arriving at the same moment as the first call. The
          # answer is the entry that won.
          existing = find_existing(account, idempotency_key)
          return existing ? success(existing) : failure(entry, :already_recorded)
        end

        saved ? success(entry) : failure(entry, entry.errors)
      end

      private

      def find_existing(account, idempotency_key)
        Spree::LedgerEntry.find_by(account: account, idempotency_key: idempotency_key)
      end

      # @param account [Object]
      # @return [String]
      def unit_for(account, reverses)
        reverses ? reverses.unit : account.ledger_unit
      end

      # A reversal always moves the other way from what it undoes, whatever
      # sign the caller passed.
      #
      # @param amount [Numeric]
      # @param reverses [Spree::LedgerEntry, nil]
      # @return [Numeric]
      def signed_amount(amount, reverses)
        return amount if reverses.nil?

        reverses.amount.negative? ? amount.abs : -amount.abs
      end

      # The snapshot the column promises: where the balance stood *after* this
      # movement. The account answers where it stands *now* — which is before
      # this entry is written, because `record!` is the write — so the movement
      # is added here.
      #
      # That addition is what lets an account whose balance *is* its history
      # (the points account) carry a truthful snapshot: it has nothing else to
      # apply the movement with, and a caller that has already applied it keeps
      # no snapshot at all (`ledger_balance` answers nil, as a gift card does —
      # its `amount_used` is authoritative and a second number here would be
      # the second source of truth its plan forbids).
      #
      # @param account [Object]
      # @param amount [Numeric]
      # @return [Numeric, nil]
      def snapshot_for(account, amount)
        balance = account.ledger_balance
        balance.nil? ? nil : balance + amount
      end

      # @param account [Object]
      # @return [void]
      # @raise [Spree::Ledger::NotAnAccount]
      def assert_account!(account)
        missing = %i[ledger_unit ledger_balance].reject { |method| account.respond_to?(method) }
        return if missing.empty?

        raise NotAnAccount,
              "#{account.class} is not a ledger account: it does not answer #{missing.join(' or ')}"
      end
    end
  end
end
