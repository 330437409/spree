module Spree
  module PaymentPins
    # Closing the PIN — the client's 关闭支付密码.
    #
    # The prompt stops being asked for; the PIN itself stays, so a customer who
    # turns it back on does not have to think up another one. What destroys a
    # PIN is erasure, not this: the row is a credential the customer owns, and
    # this is them saying they no longer want to be asked for it.
    #
    # Both proofs are required, because this is the switch that decides whether
    # a balance spend is guarded at all: the PIN itself, which also counts a
    # wrong guess against the lockout, and a code to the customer's own number.
    class Close
      prepend Spree::ServiceModule::Base

      # @param store [Spree::Store]
      # @param customer [Object]
      # @param pin [String] the PIN the customer has now
      # @param code [String] a `payment` code sent to their own number
      # @return [Spree::ServiceModule::Result] value is the PIN row
      def call(store:, customer:, pin:, code:)
        record = Spree::PaymentPin.find_by(store: store, customer: customer)
        return failure(nil, :pin_missing) if record.nil?

        unless Spree::VerificationCode.consume(phone: customer.phone, purpose: 'payment', code: code)
          # A message rather than a symbolic type — see Spree::PaymentPins::Set.
          record.errors.add(:code, Spree.t('verification_codes.errors.code_invalid'))
          return failure(record)
        end

        unless record.verify(pin)
          record.record_failed_attempt!
          record.errors.add(:pay_password, Spree.t('verification_codes.pin.invalid'))
          return failure(record)
        end

        record.required = false
        return failure(record) unless record.save

        success(record)
      end
    end
  end
end
