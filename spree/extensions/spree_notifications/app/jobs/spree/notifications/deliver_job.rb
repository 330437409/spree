module Spree
  module Notifications
    # The enqueue half of the door: `Spree::Notifications.deliver` hands the
    # message to this job so no request waits on a vendor.
    #
    # It inherits {Spree::BaseJob}, which retries infrastructure errors and
    # discards a job whose record is gone — a message about something that no
    # longer exists is not worth replaying. A vendor that refuses is reported
    # rather than raised past this point, because a second attempt would send
    # a second message: for a verification code that is a second charge and a
    # customer holding two codes, one of which will fail.
    class DeliverJob < Spree::BaseJob
      # ActiveJob logs every job's arguments, and one of these is a
      # verification code in clear — a five-minute credential that a log line
      # would keep readable long after it expired.
      self.log_arguments = false

      # @param to [Object] the recipient, re-loaded from its GlobalID when it
      #   was a record, or the bare address when it was not
      # @param event [String]
      # @param payload [Hash]
      # @param store [Spree::Store, nil]
      def perform(to:, event:, payload: {}, store: nil)
        Spree::Notifications.deliver_now(to: to, event: event, payload: payload, store: store)
      end
    end
  end
end
