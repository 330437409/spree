# spree_memberships

The membership ladder: which rung a customer is on, and what each rung carries.

There is no tier table. A tier **is** a `Spree::CustomerGroup` — the audience
model this repository already has, with its name, its members and its catalogue
assignments — plus one `Spree::MembershipTierSetting` row that gives it a rank, a
threshold and a term length. That row is what makes a group a tier rather than
some other audience, and it has no name and no member list of its own.

```ruby
SpreeMemberships.membership_rights << MyGem::Rights::FreeShipping
```

## What ships

| Piece | What it is |
| --- | --- |
| `Spree::MembershipTierSetting` | A group's rung: its rank, what qualifies for it, and how many days a term of it lasts |
| `Spree::MembershipRight` | What a tier grants, as an STI row whose kind is a registered class |
| `Spree::MembershipRights::*` | The ten built-in kinds — `member_price`, `exclusive_coupon`, `coupon`, `large_coupon`, `add_bag`, `priority_distribution`, `birthday_double_integral`, `give_gift`, `surprise_red_envelope`, `svip_date` |
| `SpreeMemberships.membership_rights` | The registry a gem adds a kind to |
| `Spree::Memberships::MemberCentre` | The projection the member centre reads: every right of the store's ladder, grouped by the panel its kind declares |
| `Spree::Memberships::YearGift` | One member's annual gift: the coupons it offers, the ones they have taken this year, and what is left of the year's allowance |
| `Spree::Memberships::ClaimYearGift` | 立即领取 — draws one of the gift's coupons, hands it over through the wallet and records the claim, all under one idempotency key |
| `Spree::Memberships::YearGiftClaim` | The kind of grant a claim is: one member, one tier, one coupon, one year |
| `Spree::MembershipBanner` | The member centre's banner: one picture per tier, and the tap targets laid over it |
| `Spree::MembershipCard` | What a membership is bought, granted, held or given away as, before anybody is entitled to anything |
| `Spree::Membership` | The term itself: a period a named customer holds a tier for |
| `Spree::Memberships::SetMemberDiscount` | The tier's member price: a catalogue of its own, an owned automatic list and the assignment that shows it to the tier's group |
| `Spree::Memberships::MemberDiscount` | What the member price took off one order, per line — what the platform, not the seller, funded |
| `Spree::Memberships::FundMemberDiscount` | The `funded_discounts` handler that hands that figure to the seller ledger |
| `Spree::MembershipCards::Activate`, `::Recycle`, `::Expire` | The card's transitions: 激活 from either door, 作废, and the deadline |
| `Spree::Memberships::EndTerm`, `::Advance` | Ending a term (with its tier's group), and the sweep that decides each term's next state |
| `Spree::Memberships::AdvanceDueJob` | The hourly sweep. The host application registers it |

## Store API

| Method and path | What it answers |
| --- | --- |
| `GET /api/v3/store/membership_rights` | The rights catalogue: every right this store's tiers carry, published or not, each with the tier it belongs to |
| `GET /api/v3/store/membership_tiers` | The ladder, in rank order |
| `GET /api/v3/store/membership_purchase_checks?tier_id=` | What buying that package means for the terms the customer already holds. Answers `checks`, empty in the ordinary case: `overlap` names the term the purchase waits behind and the instant it ends, and `open_ended` says a term held with no end will refuse the card. Advisory — a purchase proceeds on any answer. Both sides are the store's own: another store's package is a 404, and a term held against another store's tier is not this store's business |
| `GET /api/v3/store/customers/me/membership` | The customer's own rung, its sections and how many rights it carries. A customer in no tier is answered a null tier rather than refused. A right whose kind has something of its own to say carries it here — the annual gift's coupons and both of its counts ride the entry as `gift` |
| `GET /api/v3/store/customers/me/membership_cards` | The wallet: the cards this customer bought or was granted, and what each is waiting for |
| `POST /api/v3/store/customers/me/membership_cards/:id/activations` | 激活 — the card leaves `dormant` and a term starts for the customer who activated it |
| `POST /api/v3/store/customers/me/membership_rights/:id/year_gift_claims` | 立即领取 — the annual gift: one of the tier's gift coupons is handed over and the claim recorded, once per coupon per year |
| `GET /api/v3/store/scenario_orders/:id/membership_card` | The card a settled purchase released, read back off the purchase. The purchase itself is the scenario plan's row; its history is that plan's list narrowed by `kind=vip` |
| `GET /api/v3/store/customers/me/membership_banner` | The banner the customer's member centre opens with: the picture of their tier and the tap targets over it. `null` when they are in no tier, or their tier has none |
| `GET /api/v3/store/membership_card_transfers/:token` | The voucher read before signing in: the window it is open in and the rights the card carries |
| `POST /api/v3/store/membership_card_transfers/:token/claims` | 兑换 — claim and activate in one step. The same door a phone-addressed gift uses; a voucher is simply a window nobody's number was written on |

## Admin API

| Method and path | What it answers |
| --- | --- |
| `GET /api/v3/admin/membership_rights/types` | The registry picker: every installed kind with the settings it declares, so an admin form renders whatever is installed |
| `GET`/`POST`/`PATCH`/`DELETE /api/v3/admin/customer_groups/:id/membership_rights` | What a tier carries. The kind is chosen per request; its settings are its own preferences |
| `GET`/`POST`/`PATCH /api/v3/admin/customer_groups/:id/tier_setting` | What makes the group a tier. 404 while it is not one |
| `GET /api/v3/admin/membership_cards`, `GET /api/v3/admin/memberships` | Read-only: which cards a store issued and what became of them, and who holds which tier until when |
| `POST /api/v3/admin/membership_cards/:id/recycling` | The one write: a support desk voiding a card the client cannot (a lost phone, a fraud report) |
| `GET`/`POST`/`PATCH /api/v3/admin/customer_groups/:id/banner` | The banner the group's members see: the picture's URL, a name, and the tap targets over it |

## A right is a kind, and the panels are a projection

A right is **an entitlement, not a condition** — the tier it belongs to *is* the
condition — so it has the shape of a promotion action rather than a promotion
rule, and there is no matcher to write. What varies between kinds is what they
grant and how they present, so a kind is a registered subclass with its own
`preference` declarations, exactly as commission rules and promotion actions are.

The member centre groups the same rights the rights page lists flat, and **the
grouping is a projection**: a kind declares the panel it presents in
(`presents_as`), the read groups live rights by that declaration, and a kind that
declares an existing panel joins it with no change to the serializer. Nothing in
the backend enumerates the panels — the moment a serializer held that list,
adding a kind would be a server change again and the registry would earn nothing.

The tier's **name** is the group's own and its **rank** is the server's number:
the client maps no key and derives no order, so adding, renaming or renumbering a
tier costs no client release.

## The member price, and who pays for it

A tier's price is **a percentage off the shelf price**, and it reaches the member
the way any audience price does: through a catalogue assigned to the tier's
group. The gem stands that catalogue up for the tier — empty assortment, so it
prices the shop rather than curating it, with an owned automatic list that
derives the discounted price from the variant's own — and the percentage is set
in the same request as the tier:

```ruby
tier.update!(member_discount_percentage: 10)   # 10% off, read back from the list
```

**The operator funds it, so the operator pays the seller for it.** A member pays
less than the shelf price; the seller must still be paid as though they had not.
The gem measures what the member price took off each line and contributes it to
the seller ledger, which writes a `subsidy` row beside the earning for the
reduction less the commission the platform did not charge on it. A refund takes
the subsidy back at exactly the fraction it takes the earning back, so the two
always move together.

What counts is the line's own record of the list that priced it: a promotion, a
store-wide price list or a price the seller set is the seller's concession and is
contributed by nobody.

## The card is the instrument, the term is the entitlement

A membership is **two rows**, because a card and a term answer different
questions. A card is bought, held, given away, claimed and voided before anybody
is entitled to anything; a term is a period a named customer holds a tier for. A
customer can hold several dormant cards at once, and a card given away stays in
the giver's record while the entitlement goes to whoever claimed it — which is
why the buyer does not move when a card is claimed.

Activating a card is one transition from two doors (自己激活 and 领取 are the same
work), and it writes the term with the tier's own length:

```ruby
Spree::MembershipCards::Activate.call(card: card, customer: claimer)
```

**A term and the tier's group move together, or not at all.** Member pricing
reads the group, so a term that runs now assigns it in the same transaction, a
term that ends leaves it, and a term that expires hands the customer to their
next one. A card bought while another tier still runs does not take it out from
under them: the term is written and waits for the tier it replaces — the client's
own 自{lowEndTime}起 promise — so a customer is never on two tiers.

That wait is computed once, by `Spree::Membership.arrival_for`, and both the
activation and the pre-purchase check read it. A customer is therefore warned
about the wait they will get rather than about a second computation of it that
agrees today.

**The sweep advances every window.** `Spree::Memberships::AdvanceDueJob` starts
the terms whose window opened (moving the group), renews the ones a tier renews
by itself (`auto_renew`), puts a lapsed one into its grace window (`grace_days`)
and ends the ones that ran out — and expires the dormant cards whose deadline to
be activated passed. The host application registers it as a recurring task:

```yaml
# config/recurring.yml
advance_memberships:
  class: Spree::Memberships::AdvanceDueJob
  queue: default
  schedule: every hour at minute 5
```

## Coming from spree_crm's membership engine

`.custom-extensions/spree_crm` ran a membership engine of its own until this gem
replaced it (ruled 2026-09-18): two engines adding customers to one tier's group
is two writers of the price. Its three useful pieces were ported rather than
re-invented — `auto_renew`, `grace_days` and the purchasable SKU onto the tier
settings row — and its plan's group becomes a tier, its memberships become terms:

```bash
bin/rails spree_memberships:migrate_crm_memberships
```

The task is idempotent and leaves the CRM tables where they are: they are the
record of what that engine said.

## What this gem does not do

- **No tier table and no level table.** A tier is the group plus its settings row.
- **No rights as an enum, a constant list or a serializer branch.** Ten built-in
  kinds are the ones that ship, not a closed set.
- **No member prices of the tier's own beyond the percentage** — the tier's
  catalogue prices nothing itself; it carries one automatic list, so a merchant
  who wants per-product member prices edits that list rather than a new field.
- **No gift transfer yet.** 相赠 and 领取 arrive with the shared `Spree::Transfer`
  primitive, which the coupon wallet and the gift cards use too
  (`6.1-transfer-primitive.md`); the card's activation already takes the customer
  the claim will name.
- **No purchase yet.** Buying a term is the `vip` kind of a scenario order, and
  it arrives with the plan that owns what a purchase costs and issues
  (`6.1-scenario-purchases.md`); a card today is granted, not sold.
- **No grants yet.** The activation gift bag, the annual gift and the member day
  are the rights' own claims and the next step of the plan.
- **No per-period tally and no grant history.** The six `rights/*` endpoints the
  client never calls are not built, so those two reads are not invented here.

Design and rulings: `docs/plans/6.1-membership-tiers-and-rights.md`.
