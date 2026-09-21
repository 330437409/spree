import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
// Pays what the order still owes from the customer's own balance. All or
// nothing: a balance that does not cover the order is refused, with the
// shortfall in the message.
const order = await client.customer.orders.storeCredits.apply('or_abc123', {
  token: '<token>',
})
// endregion:example

export { order }
