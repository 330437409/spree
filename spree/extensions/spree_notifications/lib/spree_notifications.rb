require 'spree_core'
require 'spree_notifications/errors'
require 'spree_notifications/engine'

# One sender for the messages the platform sends a person.
#
# A consumer says what happened and to whom — {Spree::Notifications.deliver} —
# and the channel that can reach that recipient decides how; nobody picks a
# transport and nobody but a channel holds a provider's credentials. The
# channels are registered subclasses of {Spree::NotificationChannel::Base}, so
# a merchant's own SMS vendor is a subclass and a registration
# (docs/plans/6.1-notifications.md).
module SpreeNotifications
end
