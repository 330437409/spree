import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
// When a line could be discounted by more than one promotion, the shopper picks
// one. The promotion has to be one of the line's `promotion_candidates`, and the
// cart comes back priced with it.
const cart = await client.carts.promotionSelection.create(
  'cart_abc123',
  {
    promotion_id: 'promo_abc123',
    line_item_id: 'li_abc123',
  },
  {
    token: '<token>',
  },
)

// endregion:example

export { cart }
