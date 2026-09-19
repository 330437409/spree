# Spree Price Contexts

The contexts a storefront asks a price in — 区域 (area), 现场推广 (on-site
promotion) and 线下 (offline) — and the read that answers which sellers hold an
offer for a product.

The client shows **one goods at up to three prices**, reached from three kinds
of page. All three send the same headers and render the same fields, so this is
three contexts for one goods rather than three goods.

## A context is a channel

Each context is a `Spree::Channel`, and the client asks for one by putting its
code in `X-Spree-Channel`:

| Context | Code | What it prices |
| --- | --- | --- |
| 区域 | `area` | A seller's regional price, for a customer whose delivery address falls in the area |
| 现场推广 | `scene` | A promoter's price, shown on the on-site pages |
| 线下 | `offline` | An offline activity's price, at an activity the operator runs |

Those codes are the client's own `cartType` words, so nothing has to be
translated between what the page sends and what the channel is called. The
channel's **name** is the operator's own text and appears nowhere on the wire —
the three above are only what the installer creates them as.

There is no parameter to add to a product read and no per-context endpoint:
`X-Spree-Channel` is resolved once at the request boundary into
`Spree::Current.channel`, and the catalogue, the price and the delivery promise
are then all answered for that one context. The price a customer is shown and
the price their order is charged are therefore the same context by
construction, not two that have to be kept in step.

A context the client sends but no channel carries falls back to the store's
default channel — a wrong price rather than a missing one, so the client sends
the header on every request.

## A seller's price is its offer's price

A seller takes part in a catalogue through its own variants — its **offers** —
so a seller's price is that offer variant's base price (`price_list_id` nil).
No price row carries a seller, no list carries one, and a per-seller price needs
no configuration at all: it is the price on the seller's variant.

A price that belongs to a *context* instead is set on a price list that the
context's channel prices through, and the order line records that list, so what
the offline channel sold at is answerable from the orders.

## Which sellers hold an offer

```bash
curl 'https://example.com/api/v3/store/products/prod_86Rf07xd4z/sellers' \
  -H 'X-Spree-API-Key: pk_xxx'
```

```json
{
  "data": [
    { "id": "sel_8Kd2…", "name": "南山区水果店", "slug": "nanshan-fruit" }
  ],
  "meta": { "count": 1, "page": 1, "limit": 25 }
}
```

The product is resolved by prefixed ID or by slug, the way the product read
resolves one — published, and inside the catalogue the request resolves — so a
product the storefront answers 404 for answers 404 here too, and an id from
another store never answers at all. The list answers *who could sell this today*
— a seller still onboarding, suspended or away is left out, the same gate a
catalogue read applies.

It deliberately does **not** answer whether a seller serves the customer's
location: that is a different question, answered by the seller routing read
(`GET /api/v3/store/location/resolve_seller` in `spree_service_areas`), and
answering it here would create a second eligibility rule that disagrees with it.

## Creating the three channels

```bash
bin/rails spree:price_contexts:install_channels
```

Creates a channel per context under every store that does not have one yet,
named in each store's admin locale and falling back to the application default
for a locale this gem ships no file for. Safe to run again; channels that
already exist — by code — are left exactly as they are, including their names.

## Reading which price a line carries

The reporting layer's vocabulary (the admin report builder, saved reports, and
anything that queries `POST /api/v3/admin/reporting/query`) gains two dimensions
from this gem:

| Dimension | Answers |
| --- | --- |
| `price_list` | Which list priced the line. A context's prices live on one, so "what did the offline channel sell at" is gross sales grouped by this |
| `price_source` | What answered the price — the platform's own pricing, a price an admin negotiated, or a pricing provider |

```bash
curl -X POST 'https://example.com/api/v3/admin/reporting/query' \
  -H 'X-Spree-API-Key: sk_…' -H 'Content-Type: application/json' \
  -d '{"metrics":["gross_sales"],"dimensions":["price_list"],"time_range":{"preset":"last_30_days"}}'
```

**A line with no price list carries a base price** — the seller's own (its offer
variant's price) or the operator's. That is the category the EU Omnibus rule
tracks, and a price list's price is segmentation, so a report that reads one
must not be read as the other. Which seller a line belongs to is the `seller`
dimension the platform already publishes, so the two answers together say whose
price it was and what set it.

## What the operator configures

The installer creates the channel and nothing more, because the rest is pricing
decisions rather than setup:

1. **A catalogue for the context**, assigned as the channel's default catalogue.
2. **A price list inside that catalogue**, either explicit rows or a list that
   derives its prices on read.

Binding a catalogue to a channel narrows that channel to the catalogue's
assortment, so an empty one hides the catalogue instead of pricing it — fill the
assortment before binding it.

An 区域 price is the seller's own and 现场推广 prices ride the promoter's
commission; a 线下 price is the operator's cost, and the seller's payout is
settled through the membership plan's subsidy when that plan lands.

## Requirements

Spree 6.1 and its Store API. The seller routing gem is optional: the contexts
work without it, and only the location question needs it.
