import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
// What the customer has collected, most recently collected first — narrowed to
// one category when a tab is selected.
const items = await client.wishlists.items.list(
  'wl_abc123',
  { category_id: 'ctg_abc123', expand: ['product'] },
  { token: '<token>' },
)

// endregion:example

export { items }
