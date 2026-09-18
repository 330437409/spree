# Audit: where our plans are siloed (2026-09-18)

> **Fork-only document.** A working list, not a plan. Ours; never submitted
> upstream. Decisions referenced here live in `fork-decisions.md`.

**Scope — our plans only.** "Ours" means the files marked `**Fork-only plan.**`
(28 plans plus `6.0-delivery-scan-events.md`, `6.0-social-login.md`,
`6.0-wechat-pay-gateway.md`). The **tracked** files under `docs/plans/` are
upstream's; they are dependencies we read and never amend, and findings about
them are **not** ours to fix — they are listed separately at the end so nobody
re-derives them.

This list came from five parallel audits (duplicate models, duplicate
endpoints, duplicate mechanisms, missing cross-references, and plans rebuilding
what core ships), run before the plan-set boundary was drawn. Everything below
has been re-attributed to the correct owner.

## Resolved on 2026-09-18 (kept as the record)

| Silo | Resolution |
| --- | --- |
| Six plans sent notifications "through the marketplace relay" — a misreading of an **upstream** plan that is a buyer-seller conversation. The phone plan even planned to "amend" it | `6.1-notifications.md` owns the platform's one system-notification sender; the relay is left alone. The architecture plan's capability row is corrected in place |
| The Cainiao province map vs the division gem — two designs for Chinese geography | The Cainiao plan is superseded, the map left with it, and the ISO→bureau crosswalk has no consumer |
| The flash-sale hold vs group buying — two implementations of one missing capability | Ruled: flash sales ships a gem-local hold, group buying generalises it into core later, migration cost stated |
| The coupon holding vs the grant row — two homes for "the customer is owed something" | The row is core, `spree_grants` owns the kinds and the service |
| **D1** — three tokenised transfers, three tables, two vocabularies | **Ruled 2026-09-18: one row.** `6.1-transfer-primitive.md` owns it, in core; routes stay per-domain; statuses are `pending`/`accepted`/`canceled` with `expired` derived; each domain implements three contract methods instead of a registry |
| **C3** — the tier plan builds `spree_memberships` beside the fork's running `Spree::CrmMembership`, and both write `Spree::CustomerGroup` | **Ruled 2026-09-18: the tier plan owns the member model.** `spree_crm`'s membership is superseded, its `auto_renew`, `grace_days`, SKU purchase and expiry sweep are ported, and it keeps relationships and company roles. One writer for the group |
| **E3 + E4** — the price preview owner named no route, and five plans wrote onto the order serializer with no merger | **Ruled 2026-09-18: the gaps plan owns both.** `POST /api/v3/store/price_preview` is the one route; the order payload is merged from a table in that plan |
| **E7** — `balancePayOrder` claimed by two plans | **Ruled 2026-09-18: the gaps plan's, at the order level.** It spends through `Spree::StoreCredits::Apply`, so the payment PIN applies |

## Closed — the same thing built more than once

| # | What is duplicated | Where | Owner | Cost if two ship |
| --- | --- | --- | --- | --- |
| ~~D1~~ | **Resolved 2026-09-18** — the three transfers were `spree_coupon_transfers`, `spree_gift_card_donations`, `spree_membership_card_transfers`; the row is now `Spree::Transfer` (`6.1-transfer-primitive.md`) | — | `6.1-transfer-primitive.md` | — |
| ~~D2~~ | **Resolved 2026-09-18** — one row shape for all three balances: `spree_ledger_entries` in core (`6.1-ledger-primitive.md`), with a polymorphic account, a signed amount, a unit, an `idempotency_key` and `reverses_entry_id` replacing three reversal conventions. **Accepted cost, and this batch's only new debt:** the distribution ledger is also a payout record, so `rate`, `level` and payout state stay beside the payout path, and that plan owes the answer before its migration step | — | `6.1-ledger-primitive.md` | — |
| ~~D3~~ | **Decided 2026-09-18: keep five, decline the extraction.** Grant kinds, membership rights (`:474`), coupon campaign types (`:56`), scenario kinds (`:54`), order-change kinds (`:157`) — the grant plan already declined `Spree::RegisteredSubclasses` with its reason (`:33`), and the two primitives ruled this day deliberately added none (the transfer and the ledger answer a duck-typed contract). Five near-identical validations, pickers and controllers, reviewed and accepted rather than unnoticed | — |
| ~~D4~~ | **Resolved 2026-09-18** — the architecture plan carries a **recurring-jobs register** (job, cadence, what breaks if it does not run, owner) with ten entries, three of them delivered, and three rules for anything added | the architecture plan's "Recurring jobs" section | the architecture plan | — |

## Closed — a capability several plans need, owned by nobody

| # | Capability | Consumers | Note |
| --- | --- | --- | --- |
| ~~U1~~ | **Resolved 2026-09-18** — one token service in `spree/providers/social_auth`, cached by appid, single-flight, read by the QR mint, the subscribe channel and the 即时配送 channel. **The evidence corrected two of our documents:** the credential is a WeChat Pay *gateway preference* pair, not a `Spree::Integration`, and the reason one owner is mandatory is WeChat's own rule that a new token invalidates the previous | — |
| ~~U2~~ | **Resolved 2026-09-18** — the public read-before-sign-in resolver is the transfer primitive's own token read (`6.1-transfer-primitive.md`), so the three domains share one instead of three | — |
| ~~U3~~ | **Resolved 2026-09-18** — the author chose **one generic share resource** over a shared contract: `POST /api/v3/store/shares` in the gaps plan, composing the client's `type`/`typeId` path grammar once, with five targets adding a row each. **Accepted cost, named in the plan:** the route carries the union of its targets' parameters, while each domain keeps its own data and resource | — |
| ~~U4~~ | **Resolved 2026-09-18** — `6.1-seller-service-area-routing.md` owns the site record read (`GET /api/v3/store/site`, with the two list reads served by the existing upstream `store/sellers`), and the three flags are seller columns delivered on it. The "two carriers" were not rivals: the client's construction decides the payload, and `store/sellers` is a different question | — |

## Closed — endpoint assignments

| # | Collision | Detail |
| --- | --- | --- |
| ~~E1~~ | **Resolved 2026-09-18, and the diagnosis was wrong in a useful way.** Row by row there was **no double claim** and **25 endpoints with no owner at all**. The wallet now declares `Scope: 65`, membership's 16 and flash sales' 4 are named, and the architecture plan's "~81" is corrected to 65 |
| ~~E2~~ | **Resolved 2026-09-18** — the surface is written: `Scope: 21, 19 ours`, two resources (activities, teams), one membership create with `join_kind`, one cancellations route, and four calls resolved elsewhere (`buyCalc` → the one preview, the link and poster → the one share payload, the reminders → the notification sender). `addRiskRecord` deferred with its reason |
| ~~E3~~ | **Resolved 2026-09-18** — the preview is the gaps plan's and its route is named there: `POST /api/v3/store/price_preview`, with a table of what each plan contributes |  |
| ~~E4~~ | **Resolved 2026-09-18** — the gaps plan merges the order payload from a table; `customer/orders` was corrected to `customers/me/orders` (`routes.rb:117`) |  |
| ~~E5~~ | **Resolved 2026-09-18, with one correction.** `order/orderReminder` points at `6.1-notifications.md` (the relay is a buyer-seller conversation and never accepted it). And `transferPage/*` was **misfiled by its name**: it is not a gift-transfer page but a decorated landing page whose `pageType` switches between `transfer`/`lottery`/`fullSpecial`, so it stays excluded with the decoration bucket and the architecture plan's exception note is corrected |
| ~~E6~~ | **Resolved 2026-09-18** — `6.1-delivery-tracking.md` owns the buyer timeline and the scan plan stays phase one; the scan plan's paragraph points there, so the reservation is closed on both sides |  |
| ~~E7~~ | **Resolved 2026-09-18** — `balancePayOrder` is the gaps plan's at the order level (`:47`), and `6.1-scenario-purchases.md:105` now points there. It spends through `Spree::StoreCredits::Apply`, so the payment PIN applies |  |

## Closed — references and ownership

| # | Issue | Plans |
| --- | --- | --- |
| ~~R1~~ | **Fixed 2026-09-18** — the scenario frame now names the five plans that register a kind with it | `6.1-scenario-purchases.md` |
| ~~R2~~ | **Fixed 2026-09-18** — the gaps plan's header now names the eleven plans it merges fields for, and it was given the `Scope` line it lacked | `6.1-store-api-miniprogram-gaps.md` |
| ~~R3~~ | **Fixed 2026-09-18** — the coupon wallet's header declares the grant row it already consumed | `6.1-coupon-wallet.md` |
| ~~R4~~ | **Fixed 2026-09-18** — the welfare grant is now a kind of the shared row with a side table for what the row does not carry, and the primitive is named in the header | `6.1-gift-card-purchase-and-transfer.md` |
| ~~R5~~ | **Fixed 2026-09-18** — the one real asymmetry was distribution's: it consumes the platform-services private upload variant and now says so | bundles → reviews/pricing/routing ✔; china-invoicing → b2b-order-documents ✔; local-delivery → membership ✔; platform-services ↔ distribution ✔ |
| ~~R6~~ | **Fixed 2026-09-18** — the gift-card plan names `6.1-membership-tiers-and-rights.md`, and the superseded plan carries a note rather than being cited as a live owner | `6.1-gift-card-purchase-and-transfer.md` |

## Closed — our plans rebuilding what core ships

| # | Claim | Reality |
| --- | --- | --- |
| ~~C1~~ | **Resolved 2026-09-18** — core computes a candidate set per line (`adjusters/promotion.rb:8-10,34-45,110-118`); what is missing is wire exposure and a stored preference. The plan now says so, names the second-computation trap, and keeps the preference's shape as the open question |  |
| ~~C2~~ | **Resolved 2026-09-18** — the plan now points at `Spree::CouponCodes::BulkGenerate` (`call(promotion:, quantity:)`, collision-safe, `insert_all`) and says what it actually adds: the wallet-side placement and the idempotency key, not a code generator |  |
| ~~C3~~ | **Resolved 2026-09-18** — `spree_crm` (`Spree::CrmMembership` + `CrmMembershipPlan`, an expiry sweep in `recurring.yml`, a purchase-by-SKU path) ran beside `6.1-membership-tiers-and-rights.md`'s `spree_memberships`, both writing `Spree::CustomerGroup`. The tier plan owns the member model now; three pieces are ported, one writer is named |

## The structural causes

1. **The Wave 0 plan names no new path.** Every plan defers to `6.1-store-api-miniprogram-gaps.md`, and its only `api/v3` strings describe routes that already exist — so each consumer either invents a path (seller-scoped-pricing's `products/:id/purchase`) or waits. Its own header names none of its four upstream dependencies either.
2. **The biggest domains are claimed by count, not by row** (coupon 85, `retail/*` 43, `teamBuy/*` 21, `invitation`+`inviteTask` 36), so row-level ownership is unverifiable from any single document.
3. **Upstream's plans were read as ours.** The relay incident is the worked example, now fixed by the boundary rule in `CLAUDE.md`.

## Decisions — all eight are ruled (2026-09-18)

The four in the first section below were ruled in the first pass; the four in the second batch (U1, U3, U4, D2 — plus D4 and the two miscounts) were ruled the same day and are recorded in `fork-decisions.md` (2026-09-18 (later), “The second batch”). **Nothing on this list is open.** The two rulings that chose the stronger option — one generic share resource, one shared ledger row — carry their accepted costs in the plans themselves, and the ledger's split (the distribution plan's payout state) is the one debt either batch created.

1. **D1** → one row, `6.1-transfer-primitive.md`, in core, with per-domain routes and three contract methods.
2. **C3** → the tier plan owns the member model; `spree_crm` keeps relationships and company roles, and its membership models, purchase subscriber and expiry job go.
3. **E3 + E4** → the gaps plan owns the preview route and merges the order payload from a table.
4. **E7** → the gaps plan owns it, at the order level, spending through `Spree::StoreCredits::Apply`.

The reasoning and the accepted trade-offs are in `fork-decisions.md` (2026-09-18 (later), “The four cross-plan rulings”).

Everything left on this list is mechanical: a header line, a table row, or a citation — and the recurring-jobs list (D4) is one document either way.

## Considered and set aside — upstream's plans, not ours

Findings about these were correctly excluded once the boundary was drawn; they are upstream's to fix, and two of them contradict upstream's own code rather than ours. Recorded here so the next audit does not re-raise them:

- `6.1-exchange-rates.md` — claims to be the repo's first outbound-HTTP recurring job; the WeChat Pay gem ships two.
- `6.1-vies-vat-validation.md` — proposes a `store_id` owner axis that core deleted on 2026-08-22 in favour of one polymorphic owner.
- `6.1-marketplace-message-relay.md` — a buyer-seller conversation, read by six of our plans as a notification sender (fixed on our side; the plan itself is fine).
- `6.1-order-stages.md`, `6.1-order-change-substrate.md`, `6.1-product-market-availability.md`, `6.1-b2b-order-documents.md` — named by no other 6.1 plan; upstream's own sequencing is their business.
