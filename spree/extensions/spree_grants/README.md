# spree_grants

One row for "the store owes this customer something": where it came from, what
it released, and when it stops being owed. A membership gift, a coupon a draw
handed over, a points lot, a welfare card, a referral reward — one table with
kinds, rather than one unrelated table per family.

The row itself lives in core (`spree_grants` / `Spree::Grant`); this gem is the
kinds and the service that writes it.

```ruby
Spree::Grants.grant!(
  store: store,
  customer: customer,
  kind: 'membership_gift',
  source: right,
  context: { right: right, period: '2026-09' },
  expires_at: 30.days.from_now,
  issued: issued_coupon
)
```

## What ships

| Piece | What it is |
| --- | --- |
| `Spree::Grant` | The row (core): owner, kind, source, what it released, `granted_at`, `expires_at`, status |
| `Spree.grant_kinds` | The registry of kinds, a core key a consumer's engine appends to |
| `Spree::Grants::Kind` | The three-method contract: `idempotency_key_for`, `consumable?`, `expires?` — plus `consume!` |
| `Spree::Grants` | The one door: `grant!`, `claim!`, `consume!`, `revoke!` |

A row is `granted` while the debt is recorded — with a holder or without one — and `claimed` when `claim!` put a holder on a row that had none. A consumer that renders "claimed or not" reads the status; one that asks "whose is this" reads the owner.

## Registering a kind

A kind is a class the plan that owns the thing defines, in its own gem, and
registers into core's registry:

```ruby
module SpreeMembership
  module GrantKinds
    class Right < Spree::Grants::Kind
      def self.idempotency_key_for(context)
        "#{context[:right].api_type}:#{context[:period]}"
      end
    end
  end
end

# config.after_initialize, next to the other registry appends
Spree.grant_kinds << SpreeMembership::GrantKinds::Right
```

The row's `kind` column stores the class's `api_type`, which is derived from
its name unless the kind pins one — so renaming a class does not change what
every stored row means. Only registered kinds may be written.

A kind consumed in part overrides `consume!` and answers with `accept` or
`refuse`; the primitive holds no balance, so the counting is the owner's:

```ruby
def self.consume!(grant)
  return refuse(grant, :nothing_left) if lot_for(grant).remaining.zero?

  SpreePoints::Spend.call(grant: grant, amount: 1)
  accept(grant)
end
```

`Spree::Grants.grant!` is idempotent by that key: a job that runs twice records
nothing the second time and is answered with the row the first run wrote. The
key's meaning is part of it — the same key is one debt, even after the row is
deleted.

## The service

| Call | What it does |
| --- | --- |
| `grant!(customer:, kind:, source:, idempotency_key:/context:, expires_at:, issued:, store:)` | Records a debt once. `idempotency_key` wins when the caller built it with the kind's own `idempotency_key_for`; otherwise the kind builds it from `context` |
| `claim!(grant, customer:)` | Gives an unclaimed grant its holder — a drawn coupon before somebody takes it. Claiming it twice by the same customer is a no-op |
| `consume!(grant)` | Hands the grant to its kind. The default stamps the row; a kind consumed in part calls the service that owns the thing |
| `revoke!(grant, reason:)` | Takes the debt back, and keeps the row as the record that it was owed |

Each answers a `Spree::ServiceModule::Result`. A refusal is the kind's word
rather than the primitive's, so a consumer can say what it means in its own
language.

## What this gem does not do

- **No amounts and no balances.** A points lot's remaining count and a card's
  value belong to the plans that own them, in their own side table keyed to the
  grant.
- **No ledger.** Nothing here sums to a balance or writes a history row.
- **No issuance.** The plan that owns the thing issues it and passes the result
  in as `issued:`. This gem records what was owed.
- **No expiry job.** `expires_at` is a date to read — `usable`, `expired` and
  `expiring_before` are queries. Nothing flips a status on a schedule.
- **No endpoints.** It has no API surface of its own; a surface belongs to the
  plan that owns the thing owed.

Design and rulings: `docs/plans/6.1-grant-and-benefit-primitive.md`.
