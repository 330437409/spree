# Spree Service Areas

Which seller serves a coordinate.

The client asks this once, before it can show a catalogue, a price or a delivery promise — and it asks it before anyone has signed in, because the answer is what the rest of the session is scoped to.

```bash
curl 'https://example.com/api/v3/store/location/resolve_seller?latitude=39.9089&longitude=116.40347' \
  -H 'X-Spree-API-Key: pk_xxx'
```

```json
{
  "matched": true,
  "match_type": "district",
  "polygon_result": "not_required",
  "stale": false,
  "distance_km": 4.8,
  "seller": { "id": "sel_8Kd2…", "name": "南山区水果店" },
  "administrative_division": { "code": "110101", "name": "东城区", "level": "district" },
  "warehouse": { "name": "南山区仓" }
}
```

A point no seller covers is an answer, not an error: the same payload with `"matched": false` and everything else null. The client has three states of its own to show for it, and which words it uses is its business.

## How an answer is produced

```text
coordinates ──► coordinate system ──► administrative path ──► the deepest binding ──► decision
                 (GCJ-02)             (reverse geocoding)      (division + polygon)
```

1. **The coordinate is normalised** to GCJ-02 by `Spree::CoordinateNormalizer`, which lives in core because the warehouse's own coordinates are written through it too. Everything downstream — polygon tests included — compares in that one system.
2. **The point is placed in the tree** by `Spree::ReverseGeocode::Resolve`: the cache answers first, the store's provider is asked when it does not, the store's fallback is asked when the first refuses, and an expired answer is served before a request fails.
3. **The deepest binding wins** in `Spree::SellerRouting::Locate`. A warehouse covers a point when its bound division is on the point's own chain of ancestors, and — when it also carries a polygon — when the polygon contains it. Candidates are ordered deepest first, so a township binding beats the district above it and the same coordinate always answers the same warehouse.

## Configuration

One setting per store, plus the key for the vendor:

```ruby
store.preferred_reverse_geocode_provider = 'tencent'
store.preferred_reverse_geocode_tencent_key = '…'
store.preferred_reverse_geocode_fallback_provider = nil  # until a second vendor is wired
store.preferred_reverse_geocode_ttl_days = 30
```

**Tencent LBS is the vendor that ships**, and the seam is what makes a second one cheap: an adapter, a mapper and a registration — no change to the resolution, the cache key or the endpoint. Its `adcode` is the bureau's own code, so its mapper walks the administrative tree rather than translating a vendor's private numbering.

## The cache

An answer is stored by **cell + provider + coordinate system + tree release**: a new release or a second vendor is a new key rather than an invalidation, and nothing has to be swept. A cell is roughly 150 metres, which is what lets one vendor call serve a street's worth of customers. **"Nothing here" is cached too** — an edge area that resolves to no division is the one most likely to be asked about again.

## What a warehouse has to carry

The binding columns are core's, on `spree_stock_locations`: `administrative_division_id` (the node it covers — a province, a city, a district or a township), and optionally a polygon that narrows it further. One active warehouse per node: binding a node another active warehouse holds is refused rather than silently replacing it, and deactivating a warehouse releases its node.

A warehouse with **no coordinates** still serves customers — routing matches on the binding and the polygon, never on the distance. The coordinates exist for the distance shown to the customer, and they are filled in by core's forward geocoding, which runs when the address columns change.

## What this gem does not do

- **It does not bridge to `Spree::DeliveryZone`.** A zone answers "may this delivery method serve this address" and is authored in the delivery profile; a binding answers "which seller serves this point" and is authored on the warehouse. Two questions, and nothing derives one from the other.
- **It does not allocate stock.** Which seller serves a customer is this gem's; which warehouse fulfils an order is the fulfillment routing's.
- **It does not serve the operator's own stock.** Only a sellable seller's warehouse is a candidate — the operator's first-party locations are allocated by fulfillment, not discovered here.

## Errors

| Status | Code | Meaning |
| --- | --- | --- |
| 400 | `parameter_missing`, `invalid_request` | a coordinate is missing, is not a number, or the coordinate system is unknown |
| 422 | `validation_error` | the coordinate is not a point on Earth |
| 503 | `reverse_geocode_unavailable` | no provider could answer and nothing was cached for that cell — the message is the provider's own |
| 200 + `"stale": true` | — | the provider was unreachable and an expired answer was served |
| 429 | `rate_limit_exceeded` | too many lookups from one client in a minute |

One limit, per store and per caller: the cache already collapses a neighbourhood into a single vendor call, and this bounds what one client can spend through it. It fails open — a cache that cannot count does not take the endpoint down with it.
