module Spree
  module PaymentPins
    # Setting or changing the PIN.
    #
    # A code to the customer's own number proves the phone and the PIN is
    # written with it; the code is spent here, inside this write, rather than
    # at the check the client makes first — which is what makes a code usable
    # once however many times it was checked
    # (docs/plans/6.1-phone-verification-and-payment-pin.md).
    class Set
      prepend Spree::ServiceModule::Base

      # @param store [Spree::Store]
      # @param customer [Object] the customer whose PIN it is
      # @param code [String] a `payment` code sent to their own number
      # @param pin [String] the new six digits
      # @param confirmation [String, nil] the same six digits again
      # @return [Spree::ServiceModule::Result] value is the PIN row
      def call(store:, customer:, code:, pin:, confirmation: nil)
        record = find_or_build(store, customer)
        # A PIN arrives as a string from a form and as a number from a client
        # that typed one; the second must not be a 500 where the first is a
        # field error.
        pin = pin.to_s
        record.pin = pin

        return failure(record) unless confirmation_matches?(record, pin, confirmation)
        # Validated before a code is spent: a PIN the server refuses must not
        # cost the customer a message.
        return failure(record) unless record.valid?

        unless Spree::VerificationCode.consume(store: store, phone: customer.phone, purpose: 'payment', code: code)
          # A message rather than a symbolic type: `code` is not an attribute
          # of a PIN, and ActiveModel reads the attribute to build a symbol's
          # message — which raises for a key the model does not have. The field
          # is still named, so a client can put the refusal under its input.
          record.errors.add(:code, Spree.t('verification_codes.errors.code_invalid'))
          return failure(record)
        end

        # A PIN that did not exist before is one to be asked for; changing an
        # existing one leaves the customer's own switch where they set it.
        record.required = true if record.new_record?
        # A new PIN starts with a clean slate: the counters belong to the
        # credential that was guessed at, and a support unlock that restored a
        # locked row would otherwise hand the customer a new PIN that is still
        # locked out.
        record.failed_attempts = 0
        record.locked_until = nil
        return failure(record) unless record.save

        success(record)
      end

      private

      # The row is looked up including the closed one — the unique index counts
      # a soft-deleted row, so a customer who comes back restores theirs rather
      # than colliding with it.
      #
      # @return [Spree::PaymentPin]
      def find_or_build(store, customer)
        record = Spree::PaymentPin.with_deleted.find_or_initialize_by(store: store, customer: customer)
        record.deleted_at = nil
        record
      end

      # @return [Boolean]
      def confirmation_matches?(record, pin, confirmation)
        return true if confirmation.blank? || confirmation == pin

        record.errors.add(:pin_confirmation, :mismatch)
        false
      end
    end
  end
end
