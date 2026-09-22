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
| `Spree::Memberships::SetMemberDiscount` | The tier's member price: a catalogue of its own, an owned automatic list and the assignment that shows it to the tier's group |
| `Spree::Memberships::MemberDiscount` | What the member price took off one order, per line — what the platform, not the seller, funded |
| `Spree::Memberships::FundMemberDiscount` | The `funded_discounts` handler that hands that figure to the seller ledger |

## Store API

| Method and path | What it answers |
| --- | --- |
| `GET /api/v3/store/membership_rights` | The rights catalogue: every right this store's tiers carry, published or not, each with the tier it belongs to |
| `GET /api/v3/store/membership_tiers` | The ladder, in rank order |
| `GET /api/v3/store/customers/me/membership` | The customer's own rung, its sections and how many rights it carries. A customer in no tier is answered a null tier rather than refused |

## Admin API

| Method and path | What it answers |
| --- | --- |
| `GET /api/v3/admin/membership_rights/types` | The registry picker: every installed kind with the settings it declares, so an admin form renders whatever is installed |
| `GET`/`POST`/`PATCH`/`DELETE /api/v3/admin/customer_groups/:id/membership_rights` | What a tier carries. The kind is chosen per request; its settings are its own preferences |
| `GET`/`POST`/`PATCH /api/v3/admin/customer_groups/:id/tier_setting` | What makes the group a tier. 404 while it is not one |

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

## What this gem does not do

- **No tier table and no level table.** A tier is the group plus its settings row.
- **No rights as an enum, a constant list or a serializer branch.** Ten built-in
  kinds are the ones that ship, not a closed set.
- **No member prices of the tier's own beyond the percentage** — the tier's
  catalogue prices nothing itself; it carries one automatic list, so a merchant
  who wants per-product member prices edits that list rather than a new field.
- **No card and no term yet.** A customer is in a tier because an operator put
  them there; the card's four transitions write the same membership later, and
  they are one writer rather than two.
- **No per-period tally and no grant history.** The six `rights/*` endpoints the
  client never calls are not built, so those two reads are not invented here.

Design and rulings: `docs/plans/6.1-membership-tiers-and-rights.md`.
