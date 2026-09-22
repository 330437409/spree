module Spree
  module Points
    # The only door into a points balance, and public because it is the seam
    # other extensions earn through: a review, a campaign or an operator's
    # adjustment subscribes to its own event and calls this, rather than
    # registering a rule this gem would have to validate.
    #
    # Every movement is a row of the shared ledger and every lot is a row of
    # the shared grant primitive. What this service owns is the account's lock,
    # the allocation order and the lot's `remaining`
    # (docs/plans/6.1-points-and-growth-value.md).
    module Ledger
      # Adds to a balance, in a lot that carries its own expiry.
      #
      # @param account [Spree::PointAccount]
      # @param amount [Integer] positive
      # @param reason [String, Spree::PointReason] why it moved: the key an
      #   operator's reason list holds, which is also the entry's kind
      # @param idempotency_key [String] supplied by the producer; a retry
      #   records nothing and answers the lot the first call wrote
      # @param source [Object, nil] what caused it: an order, a review, an
      #   adjustment
      # @param expires_at [Time, nil] refused on a balance that never expires
      # @param granted_at [Time, nil]
      # @return [Spree::ServiceModule::Result] value is the lot
      def self.credit!(account:, amount:, reason:, idempotency_key:, source: nil, expires_at: nil, granted_at: nil,
                       seller: nil, order: nil)
        Credit.call(account: account, amount: amount, reason: reason, idempotency_key: idempotency_key,
                    source: source, expires_at: expires_at, granted_at: granted_at, seller: seller, order: order)
      end

      # Takes from a balance, soonest-expiry-first.
      #
      # The key is the whole identity of the spend, so a caller that names none
      # gets one built from its source — an order spends its points once — and
      # a caller with no source either is refused rather than given a key that
      # two spends would share.
      #
      # @param account [Spree::PointAccount]
      # @param amount [Integer] positive
      # @param reason [String, Spree::PointReason]
      # @param source [Object, nil] the order or redemption the points left for
      # @param idempotency_key [String, nil]
      # @return [Spree::ServiceModule::Result] value is the ledger entry
      def self.debit!(account:, amount:, reason:, source: nil, idempotency_key: nil, reverses: nil,
                      seller: nil, order: nil)
        Debit.call(account: account, amount: amount, reason: reason, source: source,
                   idempotency_key: idempotency_key, reverses: reverses, seller: seller, order: order)
      end

      # The sum of the usable lots' `remaining` — the balance, which nothing
      # stores.
      #
      # @param account [Spree::PointAccount]
      # @return [Integer]
      def self.balance(account)
        account.balance
      end
    end
  end
end
