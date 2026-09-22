# spree_points

One ledger, two balances. 积分 (points) are earned on an order and spent in a
points shop; 成长值 (growth value) is earned the same way and never spent,
because it is what moves a customer up the membership ladder.

Neither balance is a table of this gem's. A lot is a kind of the shared grant
row (`Spree::Grant`), every movement is a row of the shared ledger
(`Spree::LedgerEntry`), and what this gem owns is the account, the lot's own
side table, the allocation trail and the service other extensions earn
through.

```ruby
Spree::Points::Ledger.credit!(
  account: account, amount: 100, reason: 'consume',
  idempotency_key: "order:#{order.id}:points", source: order, expires_at: 1.year.from_now
)

Spree::Points::Ledger.debit!(account: account, amount: 40, reason: 'consume', source: order)
Spree::Points::Ledger.balance(account) # => 60
```

## What ships

| Piece | What it is |
| --- | --- |
| `Spree::PointAccount` | One balance of one customer in one store. **No balance column**: the balance is the sum of the usable lots' `remaining`, so an expiry needs no job |
| `Spree::PointGrant` | A lot: the side table of a core grant row — `amount`, `remaining`, `reason` |
| `Spree::PointReason` | The operator's reason vocabulary, a row rather than a constant, because the client hardcodes four and a fifth should not need a release |
| `Spree::PointAllocation` | Which lots a debit drew from: the audit trail and what a reversal walks back |
| `Spree::Points::Ledger` | `credit!`, `debit!`, `balance` — the only door into a balance |
| `Spree::Points::Lot` | The registered grant kind a lot is |
| `Spree::PointProduct` | A good in the shop: what it costs in points, the money that may sit beside them, its stock, and the one thing a redemption issues |
| `Spree::PointProducts::{Coupon,VipCard,Good}` | The three kinds that ship — `coupon`, `vip_card`, `good` — each carrying exactly one payload key |

## Store API

| Method and path | What it answers |
| --- | --- |
| `GET /api/v3/store/customers/me/point_accounts` | Both balances, each with what is about to lapse, the soonest expiry date and the store's two rates — always both, zero where nothing has moved |
| `GET /api/v3/store/customers/me/point_accounts/:kind/transactions` | One balance's history, newest first, filtered by `filter=income` (收入) or `filter=revenue` (支出) |
| `GET /api/v3/store/point_products` | The shelf, paged: `category=` narrows to one label, `featured=true` answers the featured strip, and `audience=member` the resolved site's own goods beside the store's. The labels the client's tabs render come back under `meta.categories` |
| `GET /api/v3/store/point_products/:id` | One good, with the payload of the thing it issues |

## The points shop

A good prices in points — never in money — and may add money on top of them. Its
price, its stock and its shelf are the row's own facts; what a redemption
*issues* belongs to whichever plan owns that thing.

**The row declares, another plan issues.** Each kind carries exactly one payload
key on the same row, with no polymorphic source: a coupon good the campaign it
issues from, a card good the tier's customer group, a shipped good the variant it
puts on an order. A kind is a registered class, and its `api_type` is what the
wire carries, so a deployment adding a fourth registers it beside the three that
ship rather than reinterpreting a string. The coupon payload the client renders
is deliberately absent until the wallet plan supplies its shape.

**Store-wide, or one seller's.** A good names the seller whose site offers it,
or nothing for the store's own shelf. `audience=member` answers the resolved
site's goods beside the store's, and refuses the request that named no site
rather than answering a shelf with a seller's goods silently missing from it.

**Categories are a field, not a taxonomy** — the client's are a flat list of
codes, so the labels its tab strip renders travel with the page of goods, which
is where its separate category call would have looked.

## Earning and giving back

A paid order earns both balances once, on `order.paid`: the amount actually
paid over the store's rate, plus each good's own 商品积分, held to the store's
minimum and multiplied by whatever a day's rights name. A cancellation takes the
whole earn back and a return its share, each as a row pointing at what it
undoes — 消费退回, never an edit.

商品积分 is two names in the `points` namespace of a product's Custom Fields:

| Name | What it is |
| --- | --- |
| `points.extra_per_unit` | the extra points one unit of this good earns |
| `points.line_cap` | the most its lines may earn between them; empty means no cap |

## Configuring it

Five store preferences: `points_earn_rate` (currency spent per point),
`points_redeem_rate` (points needed to take one unit off),
`points_minimum_order_amount` (below it an order earns nothing),
`points_validity_days` (how long a point lives; zero means it never lapses) and
`points_expiry_warning_days` (how far ahead the balance warns).

A deployment that wants 生日双倍 or 会员日双倍 points sets
`Spree::Dependencies.points_multiplier_service` to a class answering
`call(order:)` with a number; nothing multiplies until it does.

Reasons are a list wherever the operator manages them: a move the list does not
have still happens — the read shows the key itself until a label is added.

## What this gem does not do

- **Points are not money.** No currency, no `Spree::StoreCredit`, no
  `Spree::Price`: an integer count, spendable where the operator permits.
- **Nothing is stored as a balance.** No expiry job, no status a job flips —
  `expires_at` on the lot is the truth and the balance is derived from it.
- **Allocation is soonest-expiry-first**, never oldest-first: the lot about to
  lapse is the one the customer would otherwise lose.
- **The balance belongs to the customer, not to a seller** — a customer's
  points do not fragment across shops, even though the points shop's catalogue
  may be seller-scoped.
- **It issues nothing.** A redemption's coupon or membership card is issued by
  the plan that owns it.

Design and rulings: `docs/plans/6.1-points-and-growth-value.md`.
