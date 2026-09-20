import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const count = await client.carts.count('cart_abc123', {
  token: '<token>',
})

// endregion:example

export { count }
