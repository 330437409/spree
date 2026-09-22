module Spree
  module Ledger
    # Writes one entry, once.
    #
    # See {Spree::Ledger.record!} for the keywords. Nothing here moves value: a
    # redemption, a spend and a commission calculation each do their own work
    # and pass what happened in — and where the movement touches a balance the
    # account keeps, the account has not applied it yet, because writing this
    # row *is* the account's way of applying it.
    class Record
      prepend Spree::ServiceModule::Base

      # @return [Spree::ServiceModule::Result] value is the entry, except when
      #   the key is taken by another movement, where it is that row and the
      #   refusal is `:key_reused`
      def call(account:, kind:, amount:, idempotency_key:, source: nil, unit: nil, occurred_at: nil,
               reverses: nil, metadata: nil, store: nil)
        assert_account!(account)

        return failure(nil, :key_missing) if idempotency_key.blank?

        # The account's own store, because that is what the balance belongs
        # to; the concern supplies the request's when it carries none.
        store ||= account.try(:store)

        unit = unit_for(account, reverses, unit)
        signed = signed_amount(amount, reverses)

        existing = find_existing(account, idempotency_key)
        if existing
          return answer_for(existing, kind: kind, unit: unit, amount: signed, reverses: reverses)
        end

        entry = Spree::LedgerEntry.new(
          store: store,
          account: account,
          kind: kind,
          unit: unit,
          amount: signed,
          balance_after: snapshot_for(account, signed),
          reverses_entry: reverses,
          idempotency_key: idempotency_key,
          source: source,
          occurred_at: occurred_at || Time.current,
          metadata: metadata || {}
        )

        # The insert runs in its own savepoint, so a key taken between the
        # lookup and the insert cannot leave a caller's surrounding transaction
        # aborted on PostgreSQL — the retry the key exists for arrives at the
        # same moment as the first call, inside a refund workflow's own
        # transaction, often enough to matter.
        saved = begin
          Spree::LedgerEntry.transaction(requires_new: true) { entry.save }
        rescue ActiveRecord::RecordNotUnique
          existing = find_existing(account, idempotency_key)
          return existing ? answer_for(existing, kind: kind, unit: unit, amount: signed, reverses: reverses) : failure(entry, :key_taken)
        end

        saved ? success(entry) : failure(entry, entry.errors)
      end

      private

      def find_existing(account, idempotency_key)
        Spree::LedgerEntry.find_by(account: account, idempotency_key: idempotency_key)
      end

      # The answer a key somebody already holds gets: the same movement, once,
      # or a refusal. A key reused for a *different* movement is a producer bug
      # — the distribution plan's one key per order and kind, the points plan's
      # per month — and answering `success` would drop the second movement with
      # no row written and no error anywhere.
      #
      # @return [Spree::ServiceModule::Result]
      def answer_for(existing, kind:, unit:, amount:, reverses:)
        same = existing.kind == kind &&
               existing.unit == unit &&
               existing.amount == amount &&
               existing.reverses_entry_id == reverses&.id

        same ? success(existing) : failure(existing, :key_reused)
      end

      # A reversal is in the unit of what it reverses, whatever the caller
      # passed; every other movement is in the account's own unit, or in the
      # one the caller named — a distributor earns in the order's currency, and
      # one distributor account earns in more than one.
      #
      # @param account [Object]
      # @param reverses [Spree::LedgerEntry, nil]
      # @param unit [String, nil]
      # @return [String]
      def unit_for(account, reverses, unit)
        return reverses.unit if reverses

        unit.presence || account.ledger_unit
      end

      # A reversal always moves the other way from what it undoes, whatever
      # sign the caller passed.
      #
      # @param amount [Numeric, nil]
      # @param reverses [Spree::LedgerEntry, nil]
      # @return [Numeric, nil]
      def signed_amount(amount, reverses)
        return amount if reverses.nil? || amount.nil?

        reverses.amount.negative? ? amount.abs : -amount.abs
      end

      # The snapshot the column promises: where the balance stood *after* this
      # movement. The account answers where it stands *now*, which is before
      # the movement — writing this row is how the movement is applied — so it
      # is added here.
      #
      # That addition is what lets an account whose balance *is* its history
      # (the points account) carry a truthful snapshot: it has nothing else to
      # apply the movement with, and an account that has already applied it
      # elsewhere keeps no snapshot at all (`ledger_balance` answers nil, as a
      # gift card does — its `amount_used` is authoritative and a second number
      # here would be the second source of truth its plan forbids).
      #
      # @param account [Object]
      # @param amount [Numeric, nil]
      # @return [Numeric, nil]
      def snapshot_for(account, amount)
        balance = account.ledger_balance
        balance.nil? || amount.nil? ? nil : balance + amount
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
