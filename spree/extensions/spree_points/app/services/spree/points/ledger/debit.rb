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
        def call(account:, amount:, reason:, source: nil, idempotency_key: nil, reverses: nil,
                 seller: nil, order: nil)
          whole = BigDecimal(amount.to_s)
          return failure(nil, :amount_must_be_whole) unless whole.frac.zero?
          return failure(nil, :amount_must_be_positive) unless whole.positive?

          amount = whole.to_i
          # 成长值 is never *spent* — no mall redemption, no deduction — but a
          # refund takes it back like anything else the order earned. That is a
          # correction of the history rather than a spend, which is what the
          # reversal pointer distinguishes.
          return failure(nil, :not_a_spendable_balance) if !account.points? && reverses.nil?
          return failure(nil, :reason_missing) if reason.blank?

          key = idempotency_key.presence || key_for(source)
          return failure(nil, :key_missing) if key.blank?

          reason_key = Spree::PointReason.key_for(reason)
          result = nil

          # `requires_new` is what makes the refusals below real: a caller that
          # already holds a transaction — the order's own, a workflow's — would
          # otherwise join it, and `ActiveRecord::Rollback` in a joined
          # transaction undoes nothing because no savepoint was taken.
          account.with_lock(requires_new: true) do
            # A retry is answered, not spent again: these lots have already
            # been walked once under this key.
            existing = Spree::LedgerEntry.find_by(account: account, idempotency_key: key)

            if existing
              result = success(existing)
              raise ActiveRecord::Rollback
            end

            lots = lots_for(account, reverses)

            if lots.sum(&:remaining) < amount
              result = failure(nil, :insufficient_balance)
              raise ActiveRecord::Rollback
            end

            # A spend moves the balance down; a reversal's sign is the
            # ledger's to decide, and it forces the opposite of what it undoes
            # whatever arrives here.
            recorded = Spree::Ledger.record!(account: account, kind: reason_key, amount: -amount,
                                             idempotency_key: key, source: source, reverses: reverses,
                                             seller: seller, order: order)

            if recorded.failure?
              result = failure(recorded.value, recorded.error)
              raise ActiveRecord::Rollback
            end

            allocate(entry: recorded.value, lots: lots, amount: amount)
            result = success(recorded.value)
          end

          result
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

        # Which lots a movement draws on, in order.
        #
        # A reversal gives back what the earn's own lots still hold before it
        # touches the rest of the balance: the allocation trail is what explains
        # the customer's history, and clawing back one order's points from
        # another's lot would misattribute both. A spend spends whatever is
        # closest to lapsing, because that is the lot the customer would lose.
        #
        # @return [Array<Spree::PointGrant>]
        def lots_for(account, reverses)
          ordered = account.usable_lots.soonest_first.to_a
          return ordered if reverses.nil?

          # What the reversed entry touched: a spend leaves its allocations,
          # and an earn leaves none — a lot is created beside it instead — so
          # the second look finds the lot written under the same key.
          own_ids = Spree::PointAllocation.where(ledger_entry: reverses).pluck(:point_grant_id)
          if own_ids.empty?
            own_ids = Spree::PointGrant.joins(:grant)
                                       .where(spree_grants: { idempotency_key: reverses.idempotency_key })
                                       .pluck(:id)
          end

          own, rest = ordered.partition { |lot| own_ids.include?(lot.id) }

          own + rest
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
