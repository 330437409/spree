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

## Store API

| Method and path | What it answers |
| --- | --- |
| `GET /api/v3/store/customers/me/point_accounts` | Both balances, each with what is about to lapse, the soonest expiry date and the store's two rates — always both, zero where nothing has moved |
| `GET /api/v3/store/customers/me/point_accounts/:kind/transactions` | One balance's history, newest first, filtered by `filter=income` (收入) or `filter=revenue` (支出) |

## Configuring it

Three store preferences: `points_earn_rate` (currency spent per point),
`points_redeem_rate` (points needed to take one unit off) and
`points_expiry_warning_days` (how far ahead the balance warns).

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
