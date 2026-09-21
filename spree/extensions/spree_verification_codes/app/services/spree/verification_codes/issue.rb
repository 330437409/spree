module Spree
  module VerificationCodes
    # Sends a code to a number and keeps the digest of it.
    #
    # The answer is the same whether the number belongs to a customer, to
    # nobody at all, or to somebody who has asked too often this window:
    # telling those apart is how a send endpoint becomes a way to ask which
    # numbers have accounts here
    # (docs/plans/6.1-phone-verification-and-payment-pin.md).
    class Issue
      prepend Spree::ServiceModule::Base

      # @param store [Spree::Store]
      # @param phone [String] any spelling of the number
      # @param purpose [String] `account` for every account flow, `payment`
      #   for the PIN
      # @param channel [String] `sms` or the voice fallback
      # @return [Spree::ServiceModule::Result] value is the code row, or nil
      #   when the number has asked too often — the caller answers the same
      #   either way
      def call(store:, phone:, purpose:, channel: 'sms')
        @store = store
        @phone = Spree::VerificationCode.normalize_phone(phone)
        @purpose = purpose.to_s

        return failure(nil, :phone_missing) if @phone.blank?
        return success(nil) if PhoneRateLimit.exceeded?(store: @store, phone: @phone)

        record = issue(channel)
        PhoneRateLimit.record(store: @store, phone: @phone)

        success(record)
      end

      private

      # The row is written before the message is enqueued: what this endpoint
      # promises is that the customer can be proved with a code, and a vendor
      # that refuses leaves an undeliverable code behind rather than a failed
      # request. The plaintext lives in this method and in the notification —
      # the row keeps its digest and nothing else.
      #
      # @return [Spree::VerificationCode]
      def issue(channel)
        plaintext = format('%06d', SecureRandom.random_number(1_000_000))

        record = Spree::VerificationCode.create!(
          store: @store,
          phone: @phone,
          purpose: @purpose,
          channel: channel.to_s,
          code: plaintext,
          expires_at: ttl_minutes.minutes.from_now
        )

        Spree::Notifications.deliver(
          to: @phone,
          event: event,
          payload: { code: plaintext, minutes: ttl_minutes },
          store: @store
        )

        record
      end

      # @return [String]
      def event
        @purpose == 'payment' ? 'payment_pin_code' : 'verification_code'
      end

      # @return [Integer]
      def ttl_minutes
        @store.preferred_verification_code_ttl_minutes
      end
    end
  end
end
