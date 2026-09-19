# Spree Flash Sales

秒杀 and 限时折扣 for Spree Commerce: a **window**, a **pool** and a **ticket**
that holds a unit.

A customer taps 立即抢购 and is given a ticket rather than a cart — a claim that
holds units of the activity's pool for a few minutes while they pay. The pool is
the activity's own, in three scopes at once, and it is **not stock**: the shop's
shelf still has to allow the sale, and the smaller of the two decides.

## The activity

One activity is a window (`starts_at` / `ends_at`), a pool in three scopes
(all time, per day, per time slot), the per-customer purchase caps beside it,
and the goods it sells with the activity's price each.

- **`code` is the client's two card types**: `seckill` (its own page and buy
  popup) and `discount` (the ordinary product page with a badge). One activity
  with two presentations, not two models.
- **Time slots** are the stretches an activity opens in. A slot carries its own
  pool and its own purchase cap, and it is what a claim and a 开售提醒 name.
- **A window answered from the server's clock.** Every read carries
  `server_now` beside the window, because a phone whose clock is a minute fast
  would otherwise start or end the activity early. An ended activity is simply
  absent from the lists.
- **Caps are per customer; the pool is per activity.** The client checks the
  shelf (商品库存不足), then the pool (活动库存不足), then the caps (已达活动限购数量),
  and each has its own message — so they are three facts here, not one.

## Claiming a ticket

```
POST /api/v3/store/flash_sale_tickets
  { "flash_sale_id": "fsale_…", "variant_id": "variant_…",
    "flash_sale_slot_id": "fslot_…", "quantity": 2,
    "replacing_ticket_id": "ftick_…" }
```

`replacing_ticket_id` is the ticket being replaced — a re-claim releases it in
the same transaction that grants the new one, so a customer cannot hold units
twice by asking twice. **A refusal is an answer**: the caller gets 422 with a
`reason` in `error.details` (`sold_out`, `stock_short`, `cap_reached`,
`not_started`, `ended`, `slot_required`, `already_holding`, `not_in_activity`),
which is what the client's own dialog switches on.

A ticket holds **units and not a price** — the price is settled where the client
settles it, so a claim made yesterday cannot carry yesterday's price into a
payment made today.

| Method and path | Answers |
| --- | --- |
| `GET /api/v3/store/flash_sales` | the activities a customer could buy from |
| `GET /api/v3/store/flash_sales/:id` | one activity: window, pool figures, progress, goods and both prices |
| `GET /api/v3/store/flash_sales/by_product/:product_id` | the same activity asked by the goods the buy popup is about |
| `POST /api/v3/store/flash_sale_tickets` | claim, or replace |
| `GET /api/v3/store/customers/me/flash_sale_tickets` | what this customer holds unpaid, with its deadlines |
| `POST` · `DELETE /api/v3/store/flash_sale_slots/:id/reminder` | 开售提醒: wait for a stretch to open, or stop waiting |

## The pool is not stock

A claim passes **both** the pool and the shelf. The pool is an additional cap,
never a substitute for stock, so an activity cannot sell what the shop has not
got — an activity with pool left can read 已抢光 because the shelf is empty, and
that is the honest answer.

The hold a ticket owns is deliberately not `Spree::StockReservation`: that
primitive requires a cart or an order as its owner, dies with a line item, and
subtracts from the variant's global availability — so a held pool would make the
goods look out of stock for ordinary shoppers. This gem's hold owns no
`StockLevel` and never consults the stock quantifier; it is a reserved quantity
against a pool, released by expiry, cancellation or replacement, and swept by a
job that may run late (a late sweep delays a release rather than miscounting,
because every release is guarded by its own row).

## Expiry

A ticket lapses after five minutes — the client's own 请在5分钟内完成支付 — and
that lapse is what releases the pool. **The ticket is what expires, not the
hold**: releasing a hold on its own would give the units back while the ticket
still said it held them, so the next customer could take the same units and the
customer who lapsed would stay blocked by a claim nobody cleared.

Schedule the sweep (sidekiq-cron, solid_queue recurring, a system cron calling
the rake task):

```ruby
Spree::FlashSales::ExpireTicketsJob.perform_later
```

Nothing depends on the schedule being exact — every release is guarded by its
own row, so a late sweep delays a release rather than miscounting one. A claim
also clears its own activity's lapsed claims before it counts anything, so the
busiest activity is never the one waiting for the sweep.

## What this gem does not do

- **It does not price a sale.** The settlement discount, and the activity's
  积分/优惠券 refusal flags, attach to the price preview, which
  `6.1-store-api-miniprogram-gaps.md` owns as one of three shared surfaces.
- **It does not send the 开售提醒.** It records who is waiting; delivering the
  message is `6.1-notifications.md`'s relay.
- **It does not resolve a seller.** Every read carries the request's own scope,
  like every other storefront read.
