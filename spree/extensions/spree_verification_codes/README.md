# spree_verification_codes

Proof that a caller holds a phone number, and the second factor a balance spend
asks for. One code service serves four flows — binding or changing the number,
resetting a password, closing the account and the payment PIN — because the
client verifies with one endpoint that cannot say which flow it is in, and a
distinction the server cannot enforce is worse than none.

## What ships

| Piece | What it is |
| --- | --- |
| `Spree::VerificationCode` | A code, keyed by phone and purpose, held as a BCrypt digest |
| `Spree::PaymentPin` | A customer's payment PIN: its own table, with a lockout |
| `Spree::VerificationCodes::Issue` | Generates, stores the digest, sends through `spree_notifications` |
| `Spree::VerificationCodes::Check` | Verifies without consuming — the client posts the code twice |
| `Spree.payment_verifications` | The registration that makes `Spree::StoreCredits::Apply` ask for the PIN |

## Endpoints

| Method and path | What it does |
| --- | --- |
| `POST /api/v3/store/verification_codes` | Send: `{ phone, purpose, channel, ticket }` |
| `POST /api/v3/store/verification_checks` | Check: `{ phone, code, purpose }`, non-consuming |
| `GET /api/v3/store/payment_pin` | `{ set, required }` — answered whether or not one exists |
| `PUT /api/v3/store/payment_pin` | Set or change: `{ code, pay_password, confirmation_password }` |
| `PATCH /api/v3/store/payment_pin` | The switch: `{ required }` |
| `DELETE /api/v3/store/payment_pin` | Close it: `{ code, pay_password }` |
| `DELETE /api/v3/admin/customers/:customer_id/payment_pin` | Support: clear a lockout |

`purpose` is `account` for every account flow and `payment` for the PIN, and a
code issued for one family is refused by the other where it is spent. A payment
code is only sent to a signed-in customer's own number.

## The rules that are easy to get wrong

- **The check does not consume; the write does.** The client checks a code and
  then posts the same code to the write that needs it, so consumption happens
  inside that write, exactly once.
- **Sending says nothing.** A registered number, a stranger's and one that has
  asked too often this window all answer the same, and a rate-limited send is a
  silent no-op. Only the caller's own address gets a 429.
- **The PIN is not required to exist for a customer to be asked for it**, and
  the flag a client reads (`balanceNotPassword`) is the same question the tender
  asks: there is no required PIN, so nothing to present.
- **Closing keeps the PIN.** It stops the prompt; the customer can turn it back
  on without thinking up another one. Erasure destroys it.

## Sending without an SMS account

The API never returns or logs a code. To walk a flow by hand, mint one:

```bash
cd server && bin/rails 'spree:verification_codes:issue[13800138000,account]'
```

It prints the code and refuses in production. With the store's Tencent Cloud SMS
account connected (`spree_notifications`), the endpoint sends a real message
instead.

## Tests

```bash
bundle exec rake test_app     # once, builds spec/dummy
bundle exec rspec
```
