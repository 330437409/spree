# spree_notifications

One sender for the messages a Spree platform sends a person. A consumer says what
happened and to whom; the channel that can reach that recipient decides how.

```ruby
Spree::Notifications.deliver(
  to: customer,
  event: 'verification_code',
  payload: { code: '123456', minutes: 5 },
  store: customer.store
)
```

The send is enqueued, never performed in the caller's request: a storefront must
not wait on a vendor. The caller's own record — the verification code row, the
invoice — is what makes its request answerable.

## What ships

| Piece | What it is |
| --- | --- |
| `Spree::Notifications.deliver` | The one door. Nothing else sends |
| `Spree.notification_channels` | The registry of channels, a core key an extension appends to |
| `Spree::NotificationChannel::Base` | The three-method contract: `deliver`, `consent_for`, `available_for?` |
| `Spree::NotificationChannels::Sms` | Text messages, through the store's own SMS account |
| `SpreeNotifications::Integration` | The store's Tencent Cloud SMS account: credentials, signature, templates |

Email and WeChat subscribe messages are designed but not built;
`6.1-notifications.md` owns them.

## The event vocabulary

`Spree::Notifications::EVENTS` names every event a consumer may raise, the
channel it travels over, and the payload keys its template consumes in order.
One vocabulary for the whole platform, so a second plan does not invent a key
of its own:

| Event | Channel | Template parameters |
| --- | --- | --- |
| `verification_code` | sms | `code`, `minutes` |
| `payment_pin_code` | sms | `code`, `minutes` |
| `invitation_reminder`, `invoice_resent`, `dispatch_failed`, `seckill_reminder` | — | their owners wire them when their sends land |

An event with no channel is refused loudly rather than silently sending nothing.

## Configuring SMS

Connect the store's Tencent Cloud SMS account under Settings → Integrations. It
needs the account's `SecretId`, `SecretKey` and `SmsSdkAppId`, the approved
短信签名, and one approved template id per event:

```json
{ "verification_code": "1234567" }
```

The template must accept the event's parameters in the order the table above
gives them — a Chinese SMS provider sends an approved template with numbered
placeholders, so parameter order is part of the contract.

Activating verifies the credentials and checks the configured signature is
approved on the account. A missing template is refused at send time, with the
event named.

## Tests

```bash
bundle exec rake test_app     # once, builds spec/dummy
bundle exec rspec
```
