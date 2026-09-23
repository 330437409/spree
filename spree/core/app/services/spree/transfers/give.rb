module Spree
  module Transfers
    # Hands something over: the window opens, and the thing being moved is told
    # it is on its way.
    #
    # Both in one transaction, so a thing that refuses takes the new row with it.
    # The row's own problems are answered as the record's errors — the API's
    # usual dialect, a 422 naming the fields — and a refusal as the thing's own
    # words.
    #
    # Idempotent in the way a double tap needs: a second window on one thing is
    # refused, by the validation and by the index behind it.
    class Give
      prepend Spree::ServiceModule::Base

      # @return [Spree::ServiceModule::Result] value is the transfer
      def call(from:, transferable:, to_phone:, expires_at:, message: nil)
        transfer = nil
        refusal = nil
        invalid = false

        Spree::Transfer.transaction do
          transfer = Spree::Transfer.new(
            store: transferable.try(:store),
            transferable: transferable,
            from_customer: from,
            to_phone: to_phone,
            message: message,
            expires_at: expires_at
          )

          if transfer.save
            refusal = Contract.call(:on_transfer_given, transferable, transfer)
          else
            invalid = true
          end

          raise ActiveRecord::Rollback if refusal || invalid
        end

        return failure(transfer) if invalid
        return failure(transfer, refusal) if refusal

        success(transfer)
      rescue ActiveRecord::RecordNotUnique
        # Two taps that raced past the validation: the index refused the second,
        # and the answer is the same one the validation would have given.
        failure(transfer, Spree.t('transfers.errors.already_transferring'))
      end
    end
  end
end
