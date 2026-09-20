# @spree/dashboard-plugin-product-bundles

套餐 for the Spree dashboard: the sets a store sells, and what each one costs
against its components' own prices.

The panel half of the `spree_product_bundles` extension. The gem is the back
end — model, Admin API resource, and the storefront reads — and this package is
the front end, calling it through `adminClient.request`.

## What it adds

1. **Nav entry** — "套餐" under Products in the sidebar, at
   `/$storeId/product-bundles`.
2. **A list page** — `<ResourceTable>` over the Admin API's
   `product_bundles`, with the figures the server computes: what the components
   cost one by one, what the set costs, what it saves, and how many the shelf
   can fill.
3. **Translations** — `admin.product_bundles_plugin.*`, in English and 简体中文.

## Not yet

The form. A bundle is created and edited through the Admin API today (a flat
`components` payload that is the whole set); the panel still needs the editor
that writes it — components picked as variant rows, the discount rule as an
amount or a percentage, and the computed figures shown before saving.

## Backend

`spree/extensions/spree_product_bundles` — `GET /api/v3/admin/product_bundles`,
full CRUD behind `read_product_bundles` / `write_product_bundles` key scopes and
CanCanCan, exactly like every other Admin API resource.

## Install

The host app adds it as a dependency; `spreeDashboardPlugin()` then imports it
through `virtual:spree-dashboard-plugins` before the first render.

```bash
pnpm add @spree/dashboard-plugin-product-bundles
```
