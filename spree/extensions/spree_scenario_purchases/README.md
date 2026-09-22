# spree_scenario_purchases

The purchases that are not orders. A membership term, a top-up of points, a
gift card, a coupon bundle, a place in a group buy: the mini program pays for
each of them the same way — one call, one payment, one entitlement — and Spree
had the payment half and none of the first.

This gem owns that first half once instead of six times. It adds no payment
endpoint, no order line, no shipment and no tax treatment: what it adds is a row
that says what was bought and in which channel, the session that pays for it,
and the issue step that hands the entitlement to the plan which owns it.

```ruby
SpreeScenarioPurchases.scenario_order_kinds << SpreeMembership::Kinds::Vip
```

## What ships

| Piece | What it is |
| --- | --- |
| `Spree::ScenarioOrder` | One purchase: its kind, its amount and currency, the channel it was bought in, and where it is |
| `Spree::ScenarioOrders::Kind` | What a kind answers — `price`, `offers`, `eligible?`, `issue!` and `reverse!` |
| `SpreeScenarioPurchases.scenario_order_kinds` | The registry a plan registers its kind in. **Empty here on purpose**: the frame ships before the kinds, each of which arrives with the plan that owns the thing being bought |
| `SpreeScenarioPurchases::CHANNELS` | Which payment method serves which channel — `wechat` today, `chinaums` named and unserved |

## Store API

| Method and path | What it answers |
| --- | --- |
| `GET /api/v3/store/pay_config` | What can be bought here and how: the channels with a gateway behind them, what each kind sells, and whether the customer has a payment PIN. Readable before sign-in |
| `POST /api/v3/store/scenario_orders` | Buy something. Body: `kind`, `channel`, `context` (the kind's own), and the payment `scene`/`code` the customer is paying with. The answer carries the session the client passes on to the gateway |
| `GET /api/v3/store/customers/me/scenario_orders` | The customer's own purchases. `status=open` is what the unpaid screens list; `paid`, `canceled` and `expired` narrow it further |
| `GET /api/v3/store/scenario_orders/:id` | One purchase |
| `POST /api/v3/store/scenario_orders/:id/cancellation` | Call off a purchase that was not paid for |
| `DELETE /api/v3/store/scenario_orders/:id` | Remove one from the customer's own list |

## How a purchase is paid for

**It settles through the core payment-session flow, and it has no second one.**
The frame opens a session against the purchase, the client pays with the launch
parameters that come back, and either the gateway's webhook or the customer's
own confirm call completes it. Both routes meet in one subscriber, which moves
the purchase to `paid` and asks its kind to hand over what was bought — once,
however many times the webhook arrives.

**That is why core's payment rows know this shape.** `Spree::PaymentSession` and
`Spree::Payment` each gained a nullable `scenario_order`, registered as one more
owner beside the cart, the order and the grouped checkout — a purchase with no
order is payable only once the payment row can be for one. A deployment without
this gem resolves no association for it.

## A kind is a class, and it declares both directions

`price(context)` is what one costs; `offers` is what `pay_config` lists for it;
`eligible?(customer)` is who may buy one now; `issue!(scenario_order)` is what
settling grants, and must be idempotent; `reverse!(scenario_order)` is what a
refund takes back. The frame performs none of them — it prices nothing, grants
nothing and reverses nothing, because each belongs to the plan that owns the
entitlement.

## What this gem does not do

- **No order for an entitlement.** A membership or a bundle of codes has no
  line item, no shipment, no tax and no delivery profile. Where a scenario does
  deliver goods, it is an ordinary order and this row links to it.
- **No payment endpoint per scenario or per channel.** One create and a channel
  column.
- **Nothing is granted before the money settles**, and nothing is granted twice.
- **No gateway is modified.** A channel's gateway is named, not changed.

Design and rulings: `docs/plans/6.1-scenario-purchases.md`.
