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
      # @param phone [String] the number being written
      # @param current [String, nil] the number the account holds now
      # @param code [String, nil] what the caller presented as proof
      # @return [Boolean]
      def self.certified?(phone:, current: nil, code: nil)
        return true if phone.blank?
        return true if Spree::VerificationCode.normalize_phone(phone) == Spree::VerificationCode.normalize_phone(current)

        Spree::VerificationCode.consume(phone: phone, purpose: 'account', code: code).present?
      end
    end
  end
end
