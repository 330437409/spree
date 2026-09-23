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

    class << self
      # @param from [Object] the customer giving it away
      # @param transferable [Object] the holding, the gift card, the membership card
      # @param to_phone [String] where the gift is sent
      # @param expires_at [Time] when the window closes; nothing flips a status
      # @return [Spree::ServiceModule::Result] value is the transfer
      def give!(from:, transferable:, to_phone:, expires_at:, message: nil)
        Give.call(from: from, transferable: transferable, to_phone: to_phone,
                  expires_at: expires_at, message: message)
      end

      # Claims it for a customer — signed in by now, which is why they are passed
      # in rather than read from a session. Claiming twice answers with the
      # transfer rather than moving it twice.
      #
      # @return [Spree::ServiceModule::Result] value is the transfer
      def accept!(transfer, customer:)
        Transition.call(transfer: transfer, status: 'accepted', timestamp: :accepted_at,
                        contract: :on_transfer_accepted, customer: customer)
      end

      # Takes it back while the window is open.
      #
      # @return [Spree::ServiceModule::Result] value is the transfer
      def cancel!(transfer)
        Transition.call(transfer: transfer, status: 'canceled', timestamp: :canceled_at,
                        contract: :on_transfer_canceled)
      end

      # Whether the window is still open: pending, *and* not past its date. The
      # one reader of that rule, so no caller has to remember the date — and the
      # reason the status alone is never the answer.
      #
      # @return [Boolean]
      def open?(transfer)
        transfer.present? && transfer.pending? && !transfer.expired?
      end
    end
  end
end
