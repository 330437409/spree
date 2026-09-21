module Spree
  module Orders
    # Settles what an order still owes from the customer's own stored value —
    # "pay this order from my balance", the write behind the mini program's
    # balance payment. An order is paid rather than reserved, so what the
    # service applies is captured in the same call: a checkout-status credit
    # left on a completed order pays nothing and holds money the customer can
    # no longer spend.
    #
    # The balance is spent through {Spree::StoreCredits::Apply} and never
    # through a settlement of its own, because the payment PIN is enforced
    # inside that service (docs/plans/6.1-phone-verification-and-payment-pin.md)
    # (docs/plans/6.1-store-api-miniprogram-gaps.md).
    class PayWithStoreCredit < Spree::Workflow
      # @param order [Spree::Order] the order to settle
      # @param proof [String, nil] what the customer presented for whichever
      #   verification the tender requires — the payment PIN, when they have
      #   one that is required
      def perform(order:, proof: nil)
        super

        @proof = proof

        step :ensure_something_is_owed
        step :ensure_balance_covers

        # Locked the way every other caller of the apply service locks: two
        # requests arriving together would otherwise each write payments for
        # the same outstanding balance. Only the apply is held — the capture
        # below leaves the lock, because it is the money movement.
        order.with_lock do
          step :apply
        end
        # At the same boundary every payment processing call sits behind: it
        # must not share a transaction the caller opened.
        external_step :capture

        success(order.reload)
      end

      private

      # Also the canceled case: an order called off owes nothing, and its
      # outstanding balance is zero or negative for the same reason.
      def ensure_something_is_owed
        return if order.outstanding_balance.positive?

        order.errors.add(:base, :nothing_owed, message: Spree.t('errors.messages.nothing_is_owed'))
        failure(order)
      end

      # All or nothing. The caller asked to pay the order from their balance,
      # and applying what a short balance happens to cover would answer a
      # partial payment as if the order were paid — worse than refusing, since
      # the rest is owed either way.
      def ensure_balance_covers
        return if order.total_available_store_credit >= order.outstanding_balance

        shortfall = Spree::Money.new(order.outstanding_balance, currency: order.currency).to_s
        order.errors.add(
          :base, :store_credit_insufficient,
          message: Spree.t('errors.messages.store_credit_does_not_cover_order', amount: shortfall)
        )
        failure(order)
      end

      def apply
        result = Spree.store_credit_apply_service.call(order: order, proof: @proof)
        failure(order, result.error) if result.failure?
      end

      # Exactly what this apply left in checkout. Order#process_payments! would
      # also settle whatever other tender is still unprocessed on the order —
      # money the customer did not ask this call to move.
      def capture
        order.payments.store_credits.where(status: :checkout).each do |payment|
          result = Spree.payment_capture_workflow.call(payment: payment)
          failure(order, result.error) if result.failure?
        end
      end
    end
  end
end
