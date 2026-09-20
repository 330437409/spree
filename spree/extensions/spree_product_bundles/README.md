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
GET /api/v3/store/product_bundles                    # the collection
GET /api/v3/store/product_bundles/:id                # the purchase payload
GET /api/v3/store/carts/:cart_id/product_bundles     # the sets this cart holds
```

The collection filters by component (`with_component_variant`), by category
(`in_category`, descendants included) and by status; the member carries the
components with their own prices, and the three figures a storefront shows
beside them: `goods_price` (what the components cost one by one), `price` (what
the set costs) and `saving`.

## In a cart

A set reaches a cart as its components: the client writes one line per
component through the ordinary cart write, each tagged `bundle_id` in the
line's metadata. A synchronous subscriber reads that tag, writes the group row
and recomputes the saving — there is no second add path, and the cart the
client reads back already holds the set.

```
POST /api/v3/store/carts/:cart_id/items
  { "variant_id": "variant_…", "quantity": 2,
    "metadata": { "bundle_id": "bundle_…" } }
```

What the set saves is written as one `manual`-kind discount row per component
line, allocated in proportion to what each line costs with the rounding
remainder on the last line by position — so returning one component reverses
its share rather than unwinding the whole set, and removing a component takes
its group row with it and stops the set saving anything.

`GET /api/v3/store/carts/:cart_id/product_bundles` reads the sets back as one
card each: the title, how many sets the lines hold, what they cost, what they
saved, how many more the shelf could fill, and the cart's own lines.

## In the panel

```
GET    /api/v3/admin/product_bundles        # the operator's list
POST   /api/v3/admin/product_bundles        # create one from components
PATCH  /api/v3/admin/product_bundles/:id    # edit it, or take it off sale
DELETE /api/v3/admin/product_bundles/:id    # remove it, leaving the components
```

The Admin API's own resource: full CRUD, secret-key scopes
(`read_product_bundles` / `write_product_bundles`) and CanCanCan, like every
other admin resource. The composition is written flat and it is the whole set —
a component the payload leaves out is one the operator removed:

```json
{ "title": "双人下午茶套餐", "status": "active",
  "preferred_discount_kind": "amount", "preferred_discount_value": 20,
  "components": [{ "variant_id": "variant_…", "quantity": 1 },
                 { "variant_id": "variant_…", "quantity": 2 }] }
```

## Wiring

An extension gem like the others under `spree/extensions/`: the starter's
`server/Gemfile`, the CI project list and the gem's own `Gemfile`.
