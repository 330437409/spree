module Spree
  # The platform's one system-notification sender.
  #
  # A consumer says what happened and to whom; the channel that can reach that
  # recipient decides how. Nobody picks a transport, nobody holds a provider's
  # credentials but a channel, and nobody reaches a vendor directly — which is
  # what stops a second sender from growing beside this one
  # (docs/plans/6.1-notifications.md).
  #
  # A send is enqueued rather than performed in the caller's request: a store
  # must not wait on a vendor, and a provider that refuses is the sender's
  # problem rather than the caller's. The caller's own record — a verification
  # code row, an invoice — is what makes the request answerable.
  module Notifications
    # Every event a consumer may raise, and what sending it takes.
    #
    # One vocabulary for the whole platform, fixed here so a second plan does
    # not invent a key of its own and so a merchant configures one template per
    # event rather than per caller. `params` names the payload keys a template
    # consumes, in the order the approved template numbers them.
    #
    # An event without a channel is not an oversight: its consumer has not
    # landed yet, and delivering it is refused loudly instead of quietly
    # sending nothing.
    EVENTS = {
      'verification_code' => { channel: 'sms', params: %w[code minutes] },
      'payment_pin_code' => { channel: 'sms', params: %w[code minutes] },
      'invitation_reminder' => { channel: nil, params: [] },
      'invoice_resent' => { channel: nil, params: [] },
      'dispatch_failed' => { channel: nil, params: [] },
      'seckill_reminder' => { channel: nil, params: [] }
    }.freeze

    # Sends a message to somebody, through whichever channel can reach them.
    #
    # @param to [Object] the recipient — a record answering `#phone` or
    #   `#email`, or the address itself when it belongs to nobody yet
    # @param event [String] a key of {EVENTS}
    # @param payload [Hash] what the message is about; the keys a template
    #   consumes are named in {EVENTS}
    # @param store [Spree::Store, nil] whose account sends it, defaulting to
    #   the request's own store — named explicitly by a caller that is not in a
    #   request, which is every caller that runs in a job
    # @return [void]
    def self.deliver(to:, event:, payload: {}, store: nil)
      DeliverJob.perform_later(to: to, event: event.to_s, payload: payload, store: store || Spree::Current.store)
    end

    # The delivery itself, in the job's own process. Public because the job is
    # not the only thing that may need to send synchronously — a console, a
    # test — and because the job then has nothing to add to it.
    #
    # @return [void]
    def self.deliver_now(to:, event:, payload: {}, store: nil)
      definition = EVENTS[event.to_s]
      return report_undeliverable("unknown event #{event}", event: event) if definition.nil?

      channel_class = channel_class_for(definition[:channel])
      channel = channel_class&.new
      return report_undeliverable("no channel is registered for #{definition[:channel]}", event: event) if channel.nil?
      return report_undeliverable("#{channel.channel_name} cannot reach this recipient", event: event) unless channel.available_for?(to)
      return report_undeliverable("#{channel.channel_name} has no consent for #{event}", event: event) unless channel.consent_for(to, event.to_s)

      channel.deliver(recipient: to, event: event.to_s, payload: payload, store: store)
    end

    # The payload keys an event's template consumes, in order.
    #
    # @param event [String]
    # @param payload [Hash]
    # @return [Array<String>]
    def self.params_for(event, payload)
      EVENTS.fetch(event.to_s)[:params].map { |key| payload[key] || payload[key.to_sym] }
    end

    # @param name [String, nil]
    # @return [Class, nil]
    def self.channel_class_for(name)
      return nil if name.blank?

      Spree.notification_channels.find { |channel| channel.channel_name == name }
    end

    # A message nobody can carry is a configuration mistake, not a transient
    # one: reported once, with what to fix, and never retried.
    #
    # The context names the event and the reason and deliberately not the
    # recipient — a phone number is somebody's, and an error report is not the
    # place to collect them.
    #
    # @return [nil]
    def self.report_undeliverable(reason, event:)
      Rails.error.report(SpreeNotifications::UndeliverableError.new(reason), handled: true, context: { event: event })
      nil
    end
  end
end
