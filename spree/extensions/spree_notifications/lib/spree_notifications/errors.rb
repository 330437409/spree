module SpreeNotifications
  # Nothing could carry a message: no channel is registered for the event, the
  # recipient has no address on the one that is, the channel may not send it,
  # or the store has no account configured. Every one of those is a
  # configuration or a caller's mistake rather than a transient failure, so it
  # is reported once and never retried — a message nobody can receive is not
  # made receivable by trying again (docs/plans/6.1-notifications.md).
  class UndeliverableError < StandardError; end

  # The vendor took the request and refused it. Carries the vendor's own code
  # and message rather than a summary, because the person reading it has to
  # fix an account, a template or a signature, and "delivery failed" fixes
  # none of them.
  class DeliveryError < StandardError
    # @return [String, nil] the vendor's error code
    attr_reader :code

    # @param message [String] the vendor's own words
    # @param code [String, nil] the vendor's error code
    def initialize(message, code: nil)
      @code = code
      super(message)
    end

    # @return [String]
    def to_s
      code.present? ? "#{code}: #{super}" : super
    end
  end
end
