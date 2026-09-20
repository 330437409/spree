import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const cart = await client.carts.items.batch(
  'cart_abc123',
  {
    items: [
      { variant_id: 'variant_abc123', quantity: 2 },
      { line_item_id: 'li_abc123', quantity: 3 },
    ],
  },
  {
    token: '<token>',
  },
)

// endregion:example

export { cart }
