module Spree
  # Handing something over, in three functions: give it away, claim it, take it
  # back.
  #
  # The primitive owns the journey and nothing else. What moves is the domain's:
  # when a transfer is given, accepted or cancelled, this calls the contract on
  # the thing being moved *inside its own transaction*, so the accepted transfer
  # and the move it caused commit together or not at all
  # (docs/plans/6.1-transfer-primitive.md).
  #
  # A contract method that cannot do its work raises {Refused} — the membership
  # card's activation refuses a card past its deadline, for instance — and the
  # whole transition rolls back rather than leaving an accepted transfer that
  # moved nothing.
  module Transfers
    # Raised by a thing that cannot be moved after all.
    class Refused < StandardError; end

    Result = Spree::ServiceModule::Result
    ResultError = Spree::ServiceModule::ResultError

    class << self
      # @param from [Object] the customer giving it away
      # @param transferable [Object] the holding, the gift card, the membership card
      # @param to_phone [String] where the gift is sent
      # @param expires_at [Time] when the window closes; nothing flips a status
      # @return [Spree::ServiceModule::Result] value is the transfer
      def give!(from:, transferable:, to_phone:, expires_at:, message: nil)
        transfer = nil
        refusal = nil

        Spree::Transfer.transaction do
          transfer = Spree::Transfer.new(
            store: transferable.try(:store) || Spree::Current.store,
            transferable: transferable,
            from_customer: from,
            to_phone: to_phone,
            message: message,
            expires_at: expires_at
          )

          refusal = if transfer.save
                      call_contract(:on_transfer_given, transferable, transfer)
                    else
                      transfer.errors.full_messages.to_sentence
                    end

          raise ActiveRecord::Rollback if refusal
        end

        return failure(transfer, refusal) if refusal

        success(transfer.reload)
      end

      # Claims it for a customer — signed in by now, which is why they are passed
      # in rather than read from a session. Claiming twice answers with the
      # transfer rather than moving it twice.
      #
      # @return [Spree::ServiceModule::Result] value is the transfer
      def accept!(transfer, customer:)
        return success(transfer) if transfer.accepted?
        return failure(transfer, Spree.t('transfers.errors.not_open')) unless open?(transfer)

        refusal = nil

        transfer.with_lock do
          transfer.update!(status: 'accepted', to_customer: customer, accepted_at: Time.current)
          refusal = call_contract(:on_transfer_accepted, transfer.transferable, transfer)
          raise ActiveRecord::Rollback if refusal
        end

        return failure(transfer.reload, refusal) if refusal

        success(transfer.reload)
      end

      # Takes it back while the window is open.
      #
      # @return [Spree::ServiceModule::Result] value is the transfer
      def cancel!(transfer)
        return success(transfer) if transfer.canceled?
        return failure(transfer, Spree.t('transfers.errors.not_open')) unless open?(transfer)

        refusal = nil

        transfer.with_lock do
          transfer.update!(status: 'canceled', canceled_at: Time.current)
          refusal = call_contract(:on_transfer_canceled, transfer.transferable, transfer)
          raise ActiveRecord::Rollback if refusal
        end

        return failure(transfer.reload, refusal) if refusal

        success(transfer.reload)
      end

      # Whether the window is still open: pending, *and* not past its date. The
      # one reader of that rule, so no caller has to remember the date — and the
      # reason the status alone is never the answer.
      #
      # @return [Boolean]
      def open?(transfer)
        transfer.present? && transfer.pending? && !transfer.expired?
      end

      private

      # The thing's own transition, called inside the caller's transaction. A
      # refusal is answered as its message; anything else is a bug and belongs to
      # the caller's error reporting.
      #
      # @return [String, nil] the refusal, when it refused
      def call_contract(method, transferable, transfer)
        return unless transferable.respond_to?(method)

        transferable.public_send(method, transfer)
        nil
      rescue Refused => e
        e.message
      end

      def success(value)
        Result.new(true, value, nil)
      end

      def failure(value, error)
        Result.new(false, value, ResultError.new(error))
      end
    end
  end
end
