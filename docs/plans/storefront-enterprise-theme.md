# Storefront Theme: Enterprise (Shopify) Visual Replication

> **Fork-only plan.** Ours, never submitted to `spree/spree`. The tracked
> plans beside it are upstream's and are read-only to us; our decisions are in
> `fork-decisions.md`, never in upstream's `decisions.md`.

**Status:** In Progress — Phase 0 (tokens), Phase 1 (chrome), Phase 2
(homepage) and Phase 3 (catalog pages) are in; Phase 4 (cart, checkout,
account, wholesale) remains
**Target:** `storefront/` (Next.js 16 app), not a Spree gem release
**Depends on:** storefront branch `feat/social-login`; Spree 6.0 Store API v3 (products, categories, media)
**Author:** driven by the store owner, designed with the agent
**Last updated:** 2026-09-13
**Tracking:** Linear — · GitHub — (internal theme work on a private storefront clone; no Spree upstream issue)

## Summary

We want the storefront to look and behave like Shopify's **Enterprise** theme
(<https://enterprise-theme-home.myshopify.com/>), not like the default Spree
storefront. Enterprise is an editorial, image-led commerce design: a three-tier
header with mega menus, large full-bleed banners, collection card grids, product
carousels with quick add, and a slate "service promises" band above a wide
footer. Its look comes from a small set of theme settings — three color schemes,
three fonts, a 5px button radius, and a 1590px page width.

This plan replicates that **design language and section composition** on top of
our existing catalog, without forking the storefront or rewriting it. We do it
**token-first**: because every component already reads semantic Tailwind tokens
(`bg-background`, `text-foreground`, `bg-primary`, `--radius`), restyling the
token layer in `src/app/globals.css` re-skins a large part of the app in one
move. On top of that we build a library of composable **sections** and compose
the homepage from a config file, which mirrors how Shopify sections work
without introducing a CMS.

## Key Decisions (do not deviate without discussion)

1. **Token-first, never a rewrite.** All visual change flows through
   `src/app/globals.css` and a small number of shared primitives. We keep the
   existing shadcn token contract (`--background`, `--primary`, `--border`,
   `--radius`, and the rest) so existing components restyle automatically. We do
   **not** fork or duplicate components to change their look.
2. **Sections are components with typed props, composed from one config file.**
   The homepage is a `HomeSection[]` array in `src/lib/homepage.ts` rendered by
   a `SectionRenderer`. Reordering, removing, or reskinning the homepage is a
   one-file edit, the same ergonomics the Shopify theme editor gives.
3. **We adopt the style, not the content.** The demo's footer states its
   photography and products are licensed from Hübsch and are *not* for re-use.
   We therefore copy no demo imagery. We use our own product media, and
   generated or licensed placeholder art for editorial slots.
4. **No new runtime dependency for layout or animation.** CSS, `next/image`, and
   the existing primitives come first. A carousel library is the only candidate,
   and only if the existing Swiper usage in `ProductCarousel` does not cover it.
5. **Nothing existing may break.** Cart, checkout, wholesale portal, social
   login, i18n, and accessibility stay working. Every phase ends with
   `pnpm run check`, the existing test suites, and a visual check.
6. **The first delivery is chrome, the homepage, and the catalog.** Phases 0
   through 3 ship together: tokens, global chrome, the twelve homepage sections,
   the product listing, and the product detail page. Cart, checkout, account,
   and the wholesale portal follow in Phase 4.

### Scope locked on 2026-09-12

The store owner settled the scoping questions. These are now fixed:

- **Delivery scope:** homepage, global chrome, product listing, and product
  detail (Phases 0–3).
- **Homepage sections:** the recommended twelve only. The other eight sections
  are additive later work.
- **Fonts:** adopt Figtree (headings), Mulish (body), and Nunito Sans
  (navigation) through `next/font`.
- **Category imagery:** seed images for the five root categories, with the
  product-thumbnail and placeholder fallbacks still built in for everything
  else.

## Design Details

### 1. Extracted target tokens (measured from the live theme)

These are the real values read from the Enterprise theme's own CSS custom
properties, not eyeballed from screenshots.

| Token | Value | Notes |
| --- | --- | --- |
| `--page-width` | `1590px` | wider than our current container |
| `--gutter-lg / md / sm` | `64px / 32px / 20px` | section padding |
| `--section-gap` | `64` (unit) | vertical rhythm between sections |
| `--heading-font-family` | `Figtree, sans-serif` | weight `800` |
| `--body-font-family` | `Muli, sans-serif` | weight `400`, size `16` |
| `--navigation-font-family` | `"Nunito Sans", sans-serif` | weight `700` |
| `--heading-color` | `9 3 2` (`#090302`) | warm near-black ink |
| `--btn-bg-color` | `7 7 7` (`#070707`) | hover `52 52 52` |
| `--btn-alt-*` | bg `255 255 255`, text `7 7 7` | secondary button |
| `--btn-border-radius` | `5px` | pill variant uses `50%` |
| `--btn-padding-y` | `12px` | |
| `--color-scheme-1` | bg `242 242 242`, text/heading `9 3 2` | light neutral band |
| `--color-scheme-2` | bg `73 93 99` (`#495d63`), text `255 255 255` | slate band |
| `--color-scheme-3` | bg `250 200 205` (`#fac8cd`), text `9 3 2` | pink band |
| CTA / highlight | bg `228 237 250` (`#e4edfa`), hover `208 219 236` | "Email support" style |
| Accent labels | teal `#00a6a6`, pink `#f9717f`, red `#f71735`, green `#007e12` | product/collection badges |
| Custom label | bg `35 2 46` (`#23022e`), text white | highlight card border too |

**Fonts are all available on Google Fonts.** Note that *Muli* was renamed to
**Mulish**; we load `Mulish` and alias it as the body font.

### 2. Token mapping into our Tailwind v4 theme

Our theme block (`@theme inline`) and `:root` keep their names; only the values
change, plus a new group for Enterprise-only concepts.

| Our token | New value | Replaces |
| --- | --- | --- |
| `--background` | `#ffffff` | white (unchanged) |
| `--foreground` | `#090302` | `oklch(0.145 0 0)` |
| `--primary` | `#070707` | `oklch(0.205 0 0)` |
| `--primary-foreground` | `#ffffff` | unchanged |
| `--secondary` | `#f2f2f2` | `oklch(0.97 0 0)` |
| `--muted` | `#f7f7f7` | `oklch(0.97 0 0)` |
| `--muted-foreground` | `#6b6b6b` | `oklch(0.556 0 0)` |
| `--border` / `--input` | `#e6e6e6` | `oklch(0.922 0 0)` |
| `--radius` | `5px` | `0.625rem` |
| `--font-sans` | Mulish (via `next/font`) | Geist |

New Enterprise-only tokens, added alongside the above:

```
--color-ink, --color-scheme-1-bg/-text/-heading,
--color-scheme-2-bg/-text/-heading, --color-scheme-3-bg/-text/-heading,
--color-cta, --color-cta-hover,
--color-label-teal, --color-label-pink, --color-label-red, --color-label-green,
--color-label-custom,
--page-width, --gutter-sm, --gutter-md, --gutter-lg
```

Scheme bands are exposed as small utility classes (`.scheme-1`, `.scheme-2`,
`.scheme-3`) that set background, text, and heading color together, so a section
can switch band styling with one class instead of repeating colour utilities.
Dark mode is **out of scope** for this plan; the theme is light-only and the
`.dark` block stays as it is.

The blue `--color-primary-50 … 950` ramp in `globals.css` is unused by the
Enterprise look and gets removed once a grep confirms no consumer.

### 3. Section inventory and build order

The demo homepage is 26 blocks over ~15,000px. The named Shopify sections are
the build targets; the UUID-named blocks are unnamed demo instances of the same
section types and are identified during Phase 2 from the DOM.

| Shopify section | Our component | Data source | Phase |
| --- | --- | --- | --- |
| `announcement` | `AnnouncementBar` | config (messages, locale) | 1 |
| `header` | `Header` (rework) + `MegaMenu` | root categories + children | 1 |
| `cart-drawer` | `CartDrawer` (restyle) | existing cart context | 1 |
| `footer` | `Footer` (rework) | categories, store config, regions | 1 |
| `icons-with-text` | `IconTextRow` | config (service promises) | 1 |
| `scrolling-banner` | `ScrollingBanner` | config (marquee text, promo code) | 2 |
| hero / image banner | `HeroBanner` | config + optional category image | 2 |
| `collection-list` | `CollectionList` | `getCategories()` | 2 |
| `featured-collection` | `FeaturedCollection` | `getProducts()` by category | 2 |
| `quick_links` | `QuickLinks` | config (4 tiles) | 2 |
| `image-banner` | `ImageBanner` | config + placeholder art | 2 |
| `media-with-text` | `MediaWithText` | config + category images | 2 |
| `multi-column` | `MultiColumn` | config | 2 |
| `countdown-timer` | `CountdownTimer` | config (`ends_at`) | 2 |
| `featured-product` | `FeaturedProduct` | `getProduct(slug)` | 2 |
| `link-lists` | `LinkLists` | categories | 2 |
| `product-features` | `ProductFeatureTabs` | config + products | 2 |
| `shoppable-image` | `ShoppableImage` | config hotspots | 3 |
| blog / article grid | `ArticleList` | static content module | 3 |
| testimonials | `Testimonials` | static content module | 3 |
| newsletter | `NewsletterSignup` | no backend yet — see Open Questions | 3 |
| — (not in Shopify) | `ProductCarousel` | `getProducts()` | 2 |

**Recommended first cut is 12 sections**, not all 20: `AnnouncementBar`,
`Header` + `MegaMenu`, `HeroBanner`, `CollectionList`, `FeaturedCollection`,
`ProductCarousel`, `QuickLinks`, `MediaWithText`, `IconTextRow`,
`CountdownTimer`, `FeaturedProduct`, `Footer`. The remaining eight are additive
and can land later without rework.

### 4. Data mapping and the gaps

| Need | Source | Status |
| --- | --- | --- |
| Categories / collections | `getCategories()` — 24 categories, 5 roots, 2 levels | works |
| Category images | `image_url` on all 24 categories | **all null** — gap |
| Products | `getProducts()` — 38 products, USD | works |
| Product card image | `thumbnail_url` | works (verified 200, `image/webp`) |
| Product gallery | `product.media` | **unverified** — list endpoint returns `media: []`, PDP expands it; confirm in Phase 3 |
| Navigation / mega menu | root categories with `expand: children.children` | works |
| Blog / articles | no Spree source | gap — static content module |
| Testimonials / reviews | Shopify used Judge.me | gap — static or omit |
| Newsletter | no Spree source | gap — see Open Questions |
| Payment icons | store payment methods via API | Phase 1 |

**The category image gap is the single biggest content blocker.** The
collection-list, mega-menu promos, quick-link tiles, and hero all want imagery.
Mitigation, in order: (a) seed images for the 5 root categories; (b) fall back to
a representative product `thumbnail_url`; (c) fall back to a neutral placeholder
so the layout never collapses. The fallback chain is built into the components
in Phase 2, so missing art degrades gracefully instead of breaking the page.

### 5. File architecture

```
src/components/sections/
  SectionRenderer.tsx        # switch on section.type
  AnnouncementBar.tsx  HeroBanner.tsx       CollectionList.tsx
  FeaturedCollection.tsx     ProductCarousel.tsx  QuickLinks.tsx
  ImageBanner.tsx      ShoppableImage.tsx   MediaWithText.tsx
  MultiColumn.tsx      CountdownTimer.tsx   ScrollingBanner.tsx
  FeaturedProduct.tsx  LinkLists.tsx        ArticleList.tsx
  Testimonials.tsx     IconTextRow.tsx      NewsletterSignup.tsx
src/components/layout/
  Header.tsx (rework)  MegaMenu.tsx  Footer.tsx (rework)
src/lib/homepage.ts          # HomeSection[] config
src/lib/theme.ts             # shared constants: scheme names, label tones
src/app/globals.css          # tokens
messages/*.json              # every new string, all five locales
```

Each section is a **server component** taking typed props. Only genuinely
interactive pieces (`CountdownTimer`, `ScrollingBanner` marquee, `MegaMenu`,
carousel) are client components, and each is small and leaf-level, per
`storefront/CLAUDE.md`.

### 6. Verification loop

Every phase is checked the same way:

1. Screenshot the target at 1280px, 768px, and 375px into `.tooling/theme-ref/`.
2. Screenshot our storefront at the same widths.
3. Compare side by side; list the concrete differences.
4. Fix, re-shoot, repeat until the differences are only content, not design.

`.tooling/` is untracked, so reference images never enter the repository.

## Migration Path

**Phase 0 — Foundations.** Add the three Google fonts through `next/font`. Apply
the token mapping. Add scheme utilities and Enterprise tokens. Confirm the
existing suite is green and that no page regressed visually.
*Done when:* tokens are in, `pnpm run check` and tests pass, and a screenshot
diff shows only colour/typography/radius changes.

**Phase 1 — Chrome.** Rebuild `AnnouncementBar`, `Header` (three tiers: logo +
search + account/basket, then a category row), `MegaMenu` from the category
tree, `IconTextRow`, and `Footer`. Restyle `CartDrawer` and the buttons.
*Done when:* header and footer match the reference at all three widths, the mega
menu opens from real categories, keyboard navigation works, and no layout shift
occurs on load.

Delivered, including the cart drawer, which was the last component still
carrying hardcoded greys. The listing and product pages set the sticky offset
from the header's measured height (`--header-height`) rather than a literal.

**Phase 2 — Homepage.** Build the 12 recommended sections and the config-driven
`SectionRenderer`; replace the current three-section `page.tsx`.
*Done when:* the homepage renders from `homepage.ts`, every section has a safe
empty state, and the page matches the reference at all three widths.

Delivered as twelve sections in `HOMEPAGE_SECTIONS`, rendered through the
exhaustive `SectionRenderer` switch: hero, collection list, image banner,
featured collection, quick links, product carousel, a second image banner,
multi-column story, media with text, scrolling banner, countdown and featured
product, closing with the collection link directory.

Sections without a data source at the time (image banner, multi-column,
scrolling banner, link directory) were added once their content was settled;
the remaining later candidates from the reference — shoppable image,
testimonials, blog articles and a newsletter form — still have no source and
stay outside the twelve.

**Phase 3 — Catalog.** Restyle the product listing (filter bar, grid, cards) and
the product page (gallery, variant pickers, sticky add-to-cart, accordions).
*Done when:* PLP and PDP match the reference and cart interactions still work.

Delivered. Both pages moved onto the shared `.page-shell`, and the sticky
toolbars offset from a single `--header-height` token rather than a magic
number.

- **Listing.** Centred page header; a sticky, full-bleed filter toolbar with
  the facet dropdowns, result count and sort on one line; a five-column grid at
  `xl` (four in the editorial sections) shared by the listing and the homepage
  through `ProductGrid`.
- **Cards.** Sale / pre-order / sold-out badge, price with the struck-through
  original, colour swatches from the product's real option values, and a stock
  line. All colour comes from tokens.
- **Product page.** Gallery and buy box side by side with the accordions under
  the gallery, a sticky add-to-cart bar that takes over once the buy row
  scrolls away, and colour/button variant pickers.
- **Swatch data.** The 19 colour option values had no `color_code`, so swatches
  rendered as blank circles. They were seeded with real values; merchants can
  edit them in the admin colour picker.
- **Category and wholesale pages.** Both wrap the same `ProductListing`, so
  they moved onto the shared shell too and lost their duplicate container and
  hardcoded greys. The category banner got a scrim so its title stays legible
  over merchant photography.

Deliberately **not** built, because the data source does not exist: product
brand/vendor, review stars, the Compare feature, "goes well with"
recommendations, pickup availability, and the list/grid view toggle.

**Phase 4 — Remaining pages.** Cart, checkout, account, policies, and the
wholesale portal get the same tokens and primitives.
*Done when:* the whole storefront reads as one design.

Each phase is independently shippable and leaves `main` working.

## Constraints on Current Work

These apply **now**, before any of this is implemented:

- **Never hardcode colours, fonts, radii, or spacing in a component.** Read a
  token. A hardcoded hex is the main way this plan fails.
- **Every user-visible string goes through next-intl** and is added to all five
  locale files (`en`, `de`, `es`, `fr`, `pl`), even if only English is
  translated now.
- **Server components by default.** Reach for `"use client"` only for event
  handlers, browser APIs, or state.
- **Do not copy the demo's photography, product names, or brand.** Reference it
  for layout and proportion only.
- **Do not touch checkout, cart, or payment logic** while restyling. Those
  changes are separate and must stay behaviour-neutral.
- **Keep `pnpm run check` green** and keep existing tests passing.
- **Do not add a CMS or page-builder dependency** as part of this plan.

## Open Questions

1. **Brand** — keep the "Spree Store" name and logo, or is there a real brand
   name and logo to use? Needed before the Phase 1 header and footer are final.
2. **Product galleries** — confirm how many media items each product actually
   has, since it decides how much of the product detail gallery is real.
3. **Out-of-scope sections** — blog articles, testimonials, and the newsletter
   form have no data source. They are outside the locked twelve, so they do not
   block Phases 0–3; decide later whether to add static content, a real source,
   or drop them.

## References

- Target: <https://enterprise-theme-home.myshopify.com/>
- `storefront/CLAUDE.md` — storefront conventions (server components, React 19,
  Biome, Spree SDK usage)
- `storefront/src/app/globals.css` — the token layer this plan rewrites
- `storefront/src/app/[country]/[locale]/(storefront)/layout.tsx` — where the
  header, category navigation, and footer are composed
- `docs/plans/6.0-b2b-storefront-purchasing.md` — prior storefront work in this
  repository
- `docs/plans/6.0-product-media-system.md` — Spree 6.0 media model behind
  `product.media` and `thumbnail_url`
