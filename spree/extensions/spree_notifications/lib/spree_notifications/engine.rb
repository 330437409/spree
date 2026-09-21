require 'rails/engine'

module SpreeNotifications
  class Engine < Rails::Engine
    engine_name 'spree_notifications'

    # The channel this gem ships registers itself into core's registry rather
    # than being looked up by name, so a merchant's own channel is a second
    # registration and nothing in the door changes. Registered after
    # initialization because core assigns the registry in its own initializer,
    # and engine callbacks run in load order.
    config.after_initialize do
      Spree.notification_channels << Spree::NotificationChannels::Sms
      Spree.integrations << SpreeNotifications::Integration
    end
  end
end
