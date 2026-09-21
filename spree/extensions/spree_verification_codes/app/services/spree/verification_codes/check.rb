module Spree
  module VerificationCodes
    # The non-consuming half of the proof.
    #
    # The client checks a code and then posts the same code again to the write
    # that needs it, so nothing is spent here: the write spends it. A check
    # that consumed would break the flow it exists for, and returning a token
    # instead would break it differently, because the client has nowhere to
    # carry one.
    class Check
      prepend Spree::ServiceModule::Base

      # @param phone [String]
      # @param code [String] what the customer typed
      # @param purpose [String, nil] the family the caller means. The client
      #   posts only the number and the code — one endpoint serves every flow —
      #   so a caller that does not say gets whichever family the number's
      #   newest code belongs to, and the family is enforced where the code is
      #   spent. A caller that says gets the stricter answer.
      # @return [Spree::ServiceModule::Result] value is the code row; the error
      #   is `:expired` when there is nothing left to check and `:invalid` when
      #   the code did not match
      def call(phone:, code:, purpose: nil)
        record = lookup(phone, purpose)

        return failure(nil, :expired) if record.nil?
        return success(record) if record.check!(code)

        failure(record, :invalid)
      end

      private

      # @return [Spree::VerificationCode, nil]
      def lookup(phone, purpose)
        scope = Spree::VerificationCode.where(phone: Spree::VerificationCode.normalize_phone(phone))
        scope = scope.where(purpose: purpose) if purpose.present?

        record = scope.recent_first.first
        return nil if record.nil? || record.expired? || record.attempts >= record.max_attempts
        return nil if record.consumed_at.present?

        record
      end
    end
  end
end
