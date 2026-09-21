import { describe, expect, it } from 'vitest'
import { createTestClient } from './helpers'

const opts = { token: 'guest-order-token' }

describe('cart recommendations', () => {
  it('lists what else the shopper might want', async () => {
    const { data } = await createTestClient().carts.recommendations.list(
      'cart_1',
      { limit: 12 },
      opts,
    )

    expect(data).toHaveLength(1)
    expect(data[0].name).toBe('Test Product')
  })
})
