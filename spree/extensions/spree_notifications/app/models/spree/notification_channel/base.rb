module Spree
  module NotificationChannel
    # What every channel answers, and the whole of the contract: how to send,
    # whether it may, and whether the recipient has the identity it needs at
    # all. Deliberately three methods — a consumer never asks which channel a
    # recipient is reachable on, and never learns one exists
    # (docs/plans/6.1-notifications.md).
    class Base
      include Spree::IntegrationBackedProvider

      # The name a notification names this channel by, in `EVENTS` and in the
      # store's own configuration. Derived from the class so a subclass that
      # names its transport (`...::Sms::Tencent`) needs no second declaration.
      #
      # @return [String]
      def self.channel_name
        name.demodulize.underscore
      end

      # The same name on an instance, for the door and for anything that only
      # has the channel in hand.
      #
      # @return [String]
      def channel_name
        self.class.channel_name
      end

      # Sends it, or reports why it could not be sent.
      #
      # @param recipient [Object] a record answering `#phone`/`#email`, or the
      #   address itself when it belongs to nobody yet — the phone a customer
      #   is changing to is a recipient with no record behind it
      # @param event [String] one of {Spree::Notifications::EVENTS}
      # @param payload [Hash] what the message is about
      # @param store [Spree::Store, nil] whose account sends it — the channel's
      #   credentials are the store's, so a job carries the store rather than
      #   reading the request's
      # @return [void]
      def deliver(recipient:, event:, payload:, store:)
        raise NotImplementedError
      end

      # Whether this channel may send this event to this recipient. Consent is
      # the channel's business because it is the channel's rule: WeChat grants
      # one template per event and needs the grant recorded, SMS needs none.
      #
      # @return [Boolean]
      def consent_for(recipient, event)
        true
      end

      # Whether the recipient has the identity this channel needs — a phone
      # number for SMS, an `openid` for a subscribe message, an email address
      # for email. A recipient without one is not a failure: nobody tried to
      # reach them on this channel.
      #
      # @return [Boolean]
      def available_for?(recipient)
        raise NotImplementedError
      end

      # The address a recipient is reachable at on this channel: the record's
      # own, or the value itself when the recipient is a bare address.
      #
      # @return [String, nil]
      def address_for(recipient, attribute)
        value = recipient.respond_to?(attribute) ? recipient.public_send(attribute) : recipient
        value.to_s.strip.presence
      end
    end
  end
end
