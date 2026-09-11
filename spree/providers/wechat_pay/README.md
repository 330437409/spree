# spree_wechat_pay

WeChat Pay (微信支付) payment gateway for Spree Commerce, built on the payment
session API.

Optional gem: the `spree` meta gem does not depend on it. Add it to your Gemfile
and configure credentials on the payment method in the admin.

## Extension boundary

This gem is a standalone extension. It ships no migrations, adds one gateway
class (subclassed from `Spree::Gateway`), and patches no Spree model. Its only
runtime dependency beyond `spree_core` is `faraday`, so an update to Spree does
not overwrite it.

The one capability it needs that core did not already expose — asynchronous
refunds — lives in Spree core, not in this gem: a `status` on refunds, an
idempotent `Spree::Refund#apply_status!`, and a `:refund` webhook action with
the controller and job plumbing that carry it. That capability is generic and
off by default, so no other gateway is affected. It is in core because a gateway
must not decorate core models, and it is deliberately small so it can travel
with Spree rather than with this gem.

## What it supports

Five payment scenes, sharing one gateway record:

| Scene | Where the customer pays | Needs the payer's openid |
| --- | --- | --- |
| JSAPI | Inside the WeChat browser | yes |
| Mini program | Inside a mini program | yes |
| Native | Scans a QR code | no |
| H5 | Mobile browser outside WeChat | no |
| APP | Your own native app | no |

WeChat Pay is one merchant account with several products switched on, so a single
payment method serves whichever scenes you enable.

## Limitations worth knowing before you choose it

- **Chinese yuan only.** WeChat Pay's domestic API settles in CNY, so the payment
  method only appears for orders in that currency.
- **Charged at checkout.** WeChat offers no general authorize-then-capture split,
  so a store or payment method set to authorize at checkout and capture later
  cannot use this gateway. It is refused when you save the configuration rather
  than when the first order ships.
- **Refunds settle asynchronously.** WeChat accepts a refund and reports the
  outcome later, so a refund starts as "processing" and moves to "completed" or
  "canceled" when WeChat reports back — by notification, or by a scheduled
  reconciliation job if the notification is lost.
- **No stored payment instruments.** WeChat issues no reusable token for one-off
  payments, so customers pay each time. Entrusted deduction (委托代扣) is a
  separate product with its own onboarding.

## Credentials

Set these on the payment method. Secrets are masked on read, but
`spree_payment_methods.preferences` is not encrypted at rest — treat database
dumps accordingly.

| Setting | Notes |
| --- | --- |
| Merchant number | 商户号 |
| Merchant certificate private key | The full PEM block |
| Merchant certificate serial | Shown beside the certificate in the merchant platform |
| APIv3 key | Needed to read every notification WeChat sends; without it, notifications are not sent at all |
| Verification mode | WeChat Pay public key (recommended, never expires) or platform certificates |
| Public key and key id | Public key mode only |
| Application IDs | One per scene you enable: official account, mini program, mobile app |
| Enabled scenes | Which of the five you accept |

Saving credentials runs one authenticated call, so a wrong key or a mismatched
pair is reported immediately. A method whose credentials are half filled in is
refused while you save it, naming what is still missing; a method with nothing
filled in yet is left alone as a draft. The call cannot prove WeChat can reach
your callback address — that needs a publicly reachable URL.

## Payment notifications

WeChat sends notifications to
`<your store URL>/api/v3/webhooks/payments/<payment method id>`, which Spree
serves. The URL must be HTTPS, publicly reachable, and carry no query parameters.
WeChat requires an answer within five seconds; Spree verifies the signature
synchronously and does the rest in the background.

Signatures are checked in both directions. A notification that cannot be
verified is refused, and a notification dated more than five minutes from now is
refused as well — WeChat's own rule, and the only thing that stops a captured
notification from being replayed. Answers from WeChat are verified the same way
before anything in them is believed.

## When WeChat is unavailable

Calls are made with short timeouts, and a read that fails is retried twice with
a growing wait between attempts. A call that creates a payment or a refund is
never retried automatically — an unanswered one may have been accepted, so the
outcome is looked up under the same merchant number instead.

After repeated failures against one merchant account, further calls to that
account are refused without being made for a minute, after which one call is let
through to see whether WeChat has recovered. This keeps an outage costing one
timeout per worker rather than one per request. Both scheduled sweeps stop when
they meet a refusal instead of failing once per record, and pick up on their next
run.

## Further reading

- Plan and design record: `docs/plans/6.0-wechat-pay-gateway.md`
- WeChat Pay API documentation: <https://pay.weixin.qq.com/doc/v3/merchant/4012062524>
