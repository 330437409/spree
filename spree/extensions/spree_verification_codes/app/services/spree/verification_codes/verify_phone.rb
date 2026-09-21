module Spree
  module VerificationCodes
    # What a phone write asks before it believes a number.
    #
    # Two questions answered together, because they are one: a number the
    # account already holds is not a change and needs no proof, and any other
    # is proved by an `account` code issued for it. The code is spent here,
    # inside the write that needed it, so it cannot be replayed onto a second
    # write (docs/plans/6.1-phone-verification-and-payment-pin.md).
    #
    # This is the service `Spree::Dependencies.customer_phone_verification_service`
    # names, which is how the customer write asks for proof without knowing
    # what a verification code is.
    class VerifyPhone
      # @param store [Spree::Store] whose code counts as a proof
      # @param phone [String] the number being written
      # @param current [String, nil] the number the account holds now
      # @param code [String, nil] what the caller presented as proof
      # @return [Boolean]
      def self.certified?(store:, phone:, current: nil, code: nil)
        # Compared as numbers, not as strings: "no number is no change" is
        # true of a *write* — writing no number changes nothing — and reading
        # it as proof would let a session unbind the account's number, which
        # is the one thing standing between the account and whoever holds the
        # session. A value with no digits in it is no number, whatever it
        # looks like.
        normalized = Spree::VerificationCode.normalize_phone(phone)
        return false if normalized.blank?
        return true if normalized == Spree::VerificationCode.normalize_phone(current)

        Spree::VerificationCode.consume(store: store, phone: phone, purpose: 'account', code: code).present?
      end
    end
  end
end
