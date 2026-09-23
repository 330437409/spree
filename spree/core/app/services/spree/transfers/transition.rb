module Spree
  module Transfers
    # What accepting and cancelling share: the lock, the status, the thing's own
    # transition, and the rollback a refusal takes with it.
    #
    # Both are idempotent by status — a phone that lost its connection sends the
    # same claim twice, and the second answers with the row the first wrote.
    class Transition
      prepend Spree::ServiceModule::Base

      # @param transfer [Spree::Transfer]
      # @param status [String] where it is going
      # @param timestamp [Symbol] the column that records when it got there
      # @param contract [Symbol] the method the thing answers
      # @param customer [Object, nil] who claims it, when somebody does
      # @return [Spree::ServiceModule::Result] value is the transfer
      def call(transfer:, status:, timestamp:, contract:, customer: nil)
        return success(transfer) if transfer.status == status
        return failure(transfer, Spree.t('transfers.errors.not_open')) unless Spree::Transfers.open?(transfer)

        refusal = nil

        transfer.with_lock do
          transfer.update!({ status: status, timestamp => Time.current }.merge(claimed_by(customer)))
          refusal = Contract.call(contract, transfer.transferable, transfer)
          raise ActiveRecord::Rollback if refusal
        end

        return failure(transfer.reload, refusal) if refusal

        success(transfer)
      end

      private

      def claimed_by(customer)
        customer ? { to_customer: customer } : {}
      end
    end
  end
end
