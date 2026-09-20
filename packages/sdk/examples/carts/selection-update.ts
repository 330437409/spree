import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const cart = await client.carts.selection.update(
  'cart_abc123',
  {
    selected: false,
    line_item_ids: ['li_abc123', 'li_def456'],
  },
  {
    token: '<token>',
  },
)

// endregion:example

export { cart }
