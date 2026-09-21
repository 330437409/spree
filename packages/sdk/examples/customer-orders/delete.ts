import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
// Takes the order off the customer's own history. The order itself stays —
// fulfillment, refunds and the merchant's reporting are untouched.
await client.customer.orders.delete('or_abc123', {
  token: '<token>',
})
// endregion:example
