# spree_coupon_wallet

The coupons a customer holds. Spree's own model is the inverse of what a
mini program assumes: a `Spree::CouponCode` belongs to a promotion and binds to
a cart, never to a customer, so there is no wallet, no per-customer code and no
way to give a code to a friend. This gem adds the holding beside the code, and
the campaigns that hand coupons out.

It builds no discount engine and adds no second way to apply a code: a held
coupon is spent through the ordinary cart's discount-code entry, and what a
coupon is worth is the promotion's own business.

```ruby
Spree::Coupons::Issue.call(
  promotion: promotion, customer: customer, source: 'admin',
  idempotency_key: "support:#{ticket.id}"
)

Spree::Coupons::Draw.call(campaign: campaign, customer: customer)
Spree::Coupons::Receive.call(code: 'ABCD1234', customer: customer)
```

## What ships

| Piece | What it is |
| --- | --- |
| `Spree::CouponHolding` | A coupon a customer holds: the side table of the grant row, carrying the code it is, the campaign that minted it and how it arrived |
| `Spree::Coupons::Holding` | The registered grant kind a holding is (`coupon_holding`): who is owed a coupon, when it lapses, whether it is still owed |
| `Spree::CouponCampaign` | One way a coupon reaches a customer, with the promotion whose codes it hands over |
| `Spree::CouponCampaigns::Draw` · `NewCustomer` · `SiteScoped` | The built-in kinds: anybody inside the window, an account that is still new, one site's own handout |
| `SpreeCouponWallet.coupon_campaign_types` | The registry a deployment appends a kind to |
| `Spree::Coupons::Issue` · `Draw` · `Receive` | The three ways a coupon arrives: handed over by a producer, won from a campaign, claimed from a code |

## Store API

| Method and path | What it answers |
| --- | --- |
| `GET /api/v3/store/customers/me/coupon_holdings` | The wallet, newest first. `status=unused` (未使用), `used` (已使用) or `expired` (已过期) narrows it; `status=expiring&expires_before=2026-10-01` answers what lapses before a day the customer names |
| `GET /api/v3/store/customers/me/coupon_holdings/:id` | One coupon |
| `POST /api/v3/store/customers/me/coupon_holdings` | Claims a code the customer already has into the wallet — one the platform texted them, one the operator published. Body: `{ code }` |
| `POST /api/v3/store/coupon_campaigns/:coupon_campaign_id/draws` | One draw against a campaign; the answer is the coupon it won |

## How a coupon arrives

Three doors, one writer. `Spree::Coupons::Issue` reserves a code out of the
promotion's pool — minting one through core's own `Spree::CouponCodes::BulkGenerate`
when the pool has run dry — records the grant the shared primitive owns, and
writes the holding. It is idempotent by the key it is called with, so a draw
somebody tapped twice answers the coupon the first call wrote.

**A campaign names the promotion whose codes it hands out**, and that promotion
must be one that issues individual codes: a single-code promotion's `code` is the
promotion's own and a customer cannot hold it. A campaign is also what decides
how long a coupon lives after it arrives (`valid_for_days`), because the expiry
is set when the coupon is handed over rather than when the campaign was written.

**A kind is a class.** A draw hands a coupon to anybody inside the window, a
new-customer campaign only within its own `within_days` of the account being
made, and a site-scoped campaign only where the request shopped at its site.
Each declares its settings as preferences, so a deployment adding a fourth is a
class and a registration rather than a column and a migration.

## What this gem does not do

- **Nothing is spent here.** A coupon is used when the promotion system applies
  its code to an order, through `carts/:cart_id/discount_codes` — the one
  application path. `Spree::Coupons::Holding` is not consumable for exactly that
  reason.
- **No discount engine, and no stacking.** What a coupon is worth is the
  promotion's; a wallet is a place to keep codes, not a second way to apply them.
- **No `customer_id` on `Spree::CouponCode`.** A code row can be held, released
  and given away; the holder is the holding.
- **Status is read, never stored.** A coupon is used when its code has been
  applied, expired when its date has passed, and no job flips either — the grant
  row's `expires_at` and the code's own state are the truth.
- **Transfers are not built here.** Giving a coupon to a friend is a row of the
  shared transfer primitive, and arrives with it
  (`docs/plans/6.1-transfer-primitive.md`).

Design and rulings: `docs/plans/6.1-coupon-wallet.md`.
