module Spree
  module Points
    module Ledger
      # Takes from a balance, soonest-expiry-first: the lot closest to lapsing
      # is spent first, because it is the one the customer would otherwise
      # lose.
      #
      # The account row is the lock and the balance is read inside it — the
      # balance is the sum of the lots' `remaining`, so a stored total would
      # drift from an expiry no job flips.
      class Debit
        prepend Spree::ServiceModule::Base

        # @return [Spree::ServiceModule::Result] value is the ledger entry
        def call(account:, amount:, reason:, source: nil, idempotency_key: nil)
          amount = amount.to_i
          return failure(nil, :amount_must_be_positive) unless amount.positive?
          return failure(nil, :not_a_spendable_balance) unless account.points?
          return failure(nil, :reason_missing) if reason.blank?

          key = idempotency_key.presence || key_for(source)
          return failure(nil, :key_missing) if key.blank?

          reason_key = reason.respond_to?(:key) ? reason.key : reason.to_s
          result = nil

          account.with_lock do
            # A retry is answered, not spent again: these lots have already
            # been walked once under this key.
            existing = Spree::LedgerEntry.find_by(account: account, idempotency_key: key)

            if existing
              result = success(existing)
              raise ActiveRecord::Rollback
            end

            lots = account.usable_lots.soonest_first.to_a

            if lots.sum(&:remaining) < amount
              result = failure(nil, :insufficient_balance)
              raise ActiveRecord::Rollback
            end

            recorded = Spree::Ledger.record!(account: account, kind: reason_key, amount: -amount,
                                             idempotency_key: key, source: source)

            if recorded.failure?
              result = failure(recorded.value, recorded.error)
              raise ActiveRecord::Rollback
            end

            allocate(entry: recorded.value, lots: lots, amount: amount)
            result = success(recorded.value)
          end

          result || failure(nil, :not_recorded)
        end

        private

        # Walks the lots in order, taking what each can give and recording
        # where the points came from. `remaining` is written here and nowhere
        # else.
        #
        # @return [void]
        def allocate(entry:, lots:, amount:)
          left = amount

          lots.each do |lot|
            break if left.zero?

            taken = [lot.remaining, left].min
            lot.update!(remaining: lot.remaining - taken)
            Spree::PointAllocation.create!(ledger_entry: entry, point_grant: lot, amount: taken)
            left -= taken
          end
        end

        # One order spends its points once, so the source is the identity when
        # the caller names no key.
        def key_for(source)
          return nil if source.nil?

          "debit:#{source.class.name}:#{source.id}"
        end
      end
    end
  end
end
