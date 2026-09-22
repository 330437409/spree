module Spree
  module Points
    module Ledger
      # Adds to a balance: the entry first, then the lot it comes in.
      #
      # That order is the ledger primitive's contract — the account answers the
      # balance *before* the movement and the primitive adds it — so the entry
      # is written while the lot does not exist yet, and the lot is written
      # with the amount the entry has already recorded.
      class Credit
        prepend Spree::ServiceModule::Base

        # @param reason [String, Spree::PointReason] why the balance moved; its
        #   key is the entry's kind, and a key the operator's list does not hold
        #   still moves the balance — the read then shows the key itself
        # @return [Spree::ServiceModule::Result] value is the lot
        def call(account:, amount:, reason:, idempotency_key:, source: nil, expires_at: nil, granted_at: nil)
          whole = BigDecimal(amount.to_s)
          return failure(nil, :amount_must_be_whole) unless whole.frac.zero?
          return failure(nil, :amount_must_be_positive) unless whole.positive?

          amount = whole.to_i
          return failure(nil, :key_missing) if idempotency_key.blank?
          return failure(nil, :reason_missing) if reason.blank?
          # 成长值 never expires: a date on it is a caller that has confused
          # the two balances rather than a fact to keep.
          return failure(nil, :growth_value_does_not_expire) if expires_at.present? && !account.points?

          reason_key = Spree::PointReason.key_for(reason)
          reason_record = reason.is_a?(Spree::PointReason) ? reason : Spree::PointReason.find_by(store: account.store, key: reason_key)

          lot = nil
          refused = nil

          # `requires_new` is what makes the refusals below real: a caller that
          # already holds a transaction — the order's own, a workflow's — would
          # otherwise join it, and `ActiveRecord::Rollback` in a joined
          # transaction undoes nothing because no savepoint was taken.
          account.with_lock(requires_new: true) do
            # A retry is answered, not credited again: this key already wrote a
            # lot, and the total it bumped is not bumped a second time.
            if (existing = lot_for(account, idempotency_key))
              lot = existing
              raise ActiveRecord::Rollback
            end

            recorded = Spree::Ledger.record!(account: account, kind: reason_key, amount: amount,
                                             idempotency_key: idempotency_key, source: source)

            if recorded.failure?
              refused = recorded.error
              raise ActiveRecord::Rollback
            end

            granted = Spree::Grants.grant!(store: account.store, customer: account.customer, kind: 'point_lot',
                                           source: source, idempotency_key: idempotency_key,
                                           expires_at: expires_at, granted_at: granted_at)

            if granted.failure?
              refused = granted.error
              raise ActiveRecord::Rollback
            end

            lot = Spree::PointGrant.create(grant: granted.value, account: account, reason: reason_record,
                                           amount: amount, remaining: amount)

            unless lot.persisted?
              refused = lot.errors
              raise ActiveRecord::Rollback
            end

            account.increment!(:lifetime_earned, amount)
          end

          refused ? failure(lot, refused) : success(lot)
        end

        private

        # The lot a key already wrote, found through the grant row it belongs
        # to — the grant's key is unique per store and kind, so one key is one
        # lot.
        #
        # @return [Spree::PointGrant, nil]
        def lot_for(account, idempotency_key)
          Spree::PointGrant.joins(:grant).find_by(
            account: account,
            spree_grants: { kind: 'point_lot', idempotency_key: idempotency_key }
          )
        end
      end
    end
  end
end
