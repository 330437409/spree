module Spree
  module NotificationChannels
    # Text messages, through the store's own SMS account.
    #
    # The channel owns what every SMS needs regardless of vendor — which
    # number, which template, which parameters in which order — and the
    # store's integration owns the vendor call. A merchant on another vendor
    # registers a channel of their own rather than editing this one, and the
    # consumers above it never learn which vendor answered
    # (docs/plans/6.1-notifications.md).
    class Sms < Spree::NotificationChannel::Base
      # Pinned rather than derived from the class name: an event names 'sms',
      # and a vendor that subclasses this channel (a different transport, the
      # same channel) must still answer to it — a derived name would leave the
      # deployment believing it was sending through its transport while this
      # one kept handling every message.
      #
      # @return [String]
      def self.channel_name
        'sms'
      end

      # The credentials are the store's own account, one per channel.
      #
      # @return [String]
      def self.integration_class
        'SpreeNotifications::Integration'
      end

      # @param recipient [Object] a record answering `#phone`, or the number
      #   itself — a code goes to a number that may belong to nobody yet
      # @param event [String]
      # @param payload [Hash] the keys the event's template consumes
      # @param store [Spree::Store]
      # @return [void]
      def deliver(recipient:, event:, payload:, store:)
        integration = integration_for(store)

        if integration.nil?
          return Spree::Notifications.report_undeliverable(
            "this store has no SMS account connected", event: event
          )
        end

        integration.deliver_sms(phone: phone_for(recipient), event: event, payload: payload)
      rescue SpreeNotifications::DeliveryError, SpreeNotifications::UndeliverableError => error
        # The vendor refused, or there was nothing to send with. Both are
        # reported rather than raised: the caller's own record already exists,
        # and a second attempt would send a second message — the person who
        # asked for one code would receive two. Reported once, with the
        # vendor's or the configuration's own words.
        Rails.error.report(error, handled: true, context: { event: event, channel: self.class.channel_name })
        nil
      end

      # A number this channel can reach: the client's numbers are Chinese
      # mobiles, and a record with none is not reachable here — saying so is
      # how a caller learns the customer has no phone rather than that the
      # vendor was unhappy.
      #
      # @return [Boolean]
      def available_for?(recipient)
        phone_for(recipient).match?(/\A1\d{10}\z/)
      end

      # Digits only, without the country code: a stored "+86 138 0013 8000"
      # and a typed "13800138000" are one person, and a code is keyed by the
      # number rather than by the record.
      #
      # @return [String]
      def phone_for(recipient)
        digits = address_for(recipient, :phone).to_s.gsub(/\D/, '')
        digits.sub(/\A86(?=1\d{10}\z)/, '')
      end
    end
  end
end
