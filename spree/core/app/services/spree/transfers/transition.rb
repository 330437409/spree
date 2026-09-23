module Spree
  module Transfers
    # What accepting and cancelling share: the lock, the status, the thing's own
    # transition, and the rollback a refusal takes with it.
    #
    # Both are idempotent for the hand that already did it — a phone that lost its
    # connection sends the same claim twice, and the second answers with the row
    # the first wrote — while a *different* customer holding the same forwarded
    # token is told somebody got there first rather than being handed a success
    # for a card they do not hold.
    #
    # The window is re-read under the row lock, because a claim and a
    # cancellation can arrive together: both would pass the check above, and the
    # second to take the lock would otherwise overwrite the first and land the
    # row in a status that never happened — accepted *and* canceled at once.
    class Transition
      prepend Spree::ServiceModule::Base

      # @param transfer [Spree::Transfer]
      # @param status [String] where it is going
      # @param timestamp [Symbol] the column that records when it got there
      # @param contract [Symbol] the method the thing answers
      # @param customer [Object, nil] who claims it, when somebody does
      # @return [Spree::ServiceModule::Result] value is the transfer
      def call(transfer:, status:, timestamp:, contract:, customer: nil)
        return success(transfer) if answered?(transfer, status, customer)
        return failure(transfer, Spree.t('transfers.errors.already_claimed')) if transfer.accepted?
        return failure(transfer, Spree.t('transfers.errors.not_open')) unless movable?(transfer, status)

        lost = false
        refusal = nil

        # A savepoint, not the enclosing transaction — see Give: a caller already
        # inside one would otherwise swallow the rollback a refusal depends on.
        Spree::Transfer.transaction(requires_new: true) do
          transfer.lock!

          if answered?(transfer, status, customer)
            # The request we raced did this same thing. Nothing to write.
          elsif movable?(transfer, status)
            transfer.update!({ status: status, timestamp => Time.current }.merge(claimed_by(customer)))
            refusal = Contract.call(contract, transfer.transferable, transfer)
          else
            lost = true
          end

          raise ActiveRecord::Rollback if refusal || lost
        end

        return failure(transfer.reload, Spree.t('transfers.errors.not_open')) if lost
        return failure(transfer.reload, refusal) if refusal

        success(transfer)
      end

      private

      # Whether this call is the same hand doing the same thing again: the row is
      # where the call would put it, and for a claim it is the same customer who
      # holds it. A token forwarded to a second customer is not their success.
      def answered?(transfer, status, customer)
        return false unless transfer.status == status
        return true unless status == 'accepted'

        transfer.to_customer_id.present? && transfer.to_customer_id == customer&.id
      end

      # Accepting needs a live window. Cancelling also closes one whose date has
      # passed — 作废 of a gift nobody will ever claim, and the only way a lapsed
      # window stops holding the thing it carries.
      def movable?(transfer, status)
        return false unless transfer.pending?

        status == 'canceled' || !transfer.expired?
      end

      def claimed_by(customer)
        customer ? { to_customer: customer } : {}
      end
    end
  end
end
