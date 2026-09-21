import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
// The categories any collected good falls into — the tabs above the list.
// Uncollected categories are not here, so a tab always has something behind it.
const { data: categories } = await client.wishlists.items.categories('wl_abc123', {
  token: '<token>',
})

// endregion:example

export { categories }
