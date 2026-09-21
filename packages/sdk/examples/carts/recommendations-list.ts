import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
// What else the shopper might want, read from what is already in their basket:
// the categories its goods are in, ranked by what sells, without the goods
// they already have in front of them.
const { data: recommendations } = await client.carts.recommendations.list(
  'cart_abc123',
  { limit: 12 },
  { token: '<token>' },
)

// endregion:example

export { recommendations }
