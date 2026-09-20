# Spree Product Bundles

套餐 for Spree Commerce: **a composition and a discount, not a sellable
variant**.

A bundle is a named set of goods sold for one price. It has no price, stock,
weight, shipment or reviews of its own — the components are ordinary variants,
so every one of those stays where core already puts it. Adding a bundle to a
cart writes one cart line per component and tags them with a join row; what the
set saves is an order-level discount the gem owns.

## The bundle

One row says which variants form the set: `Spree::ProductBundle` and its
`Spree::BundleComponent` rows, each a variant and a quantity.

- **Not sellable.** No variant, no price column, no stock item, no review
  surface. A cart holds the components, an order holds the components, and the
  fulfilment, weight and returns are theirs.
- **One seller per bundle**, refused at save time: the marketplace splits an
  order by seller and re-totals each child from its own lines, where a bundle's
  single price has no home.
- **The saving is a rule, not a number** — a fixed amount or a percentage, as
  two preferences on the bundle — so a component's price moving upstream moves
  the bundle's price with it.
- **Availability is the scarcest component**, expressed in bundles rather than
  in units: `min(available / quantity)`. Core's quantifier does the arithmetic,
  so reservations and backorders are already honoured and a bundle needs no
  stock of its own.
- **A component out of stock does not hide the bundle.** The set is atomic —
  there is no partial sale and no substitution — so a storefront renders the
  missing component as 已抢光 and offers the single goods alongside.

## Reading

```
GET /api/v3/store/product_bundles        # the collection
GET /api/v3/store/product_bundles/:id    # the purchase payload
```

The collection filters by component (`with_component_variant`), by category
(`in_category`, descendants included) and by status; the member carries the
components with their own prices, and the three figures a storefront shows
beside them: `goods_price` (what the components cost one by one), `price` (what
the set costs) and `saving`.

## Wiring

An extension gem like the others under `spree/extensions/`: the starter's
`server/Gemfile`, the CI project list and the gem's own `Gemfile`.
