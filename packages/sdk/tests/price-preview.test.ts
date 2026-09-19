import { describe, expect, it } from 'vitest'
import { createTestClient } from './helpers'

describe('pricePreview', () => {
  it('prices a set of variants without a cart', async () => {
    const client = createTestClient()

    const preview = await client.pricePreview.create({
      items: [{ variant_id: 'variant_1', quantity: 2 }],
    })

    expect(preview.currency).toBe('USD')
    expect(preview.total).toBe(200)
    expect(preview.purchasable).toBe(true)
    expect(preview.items[0].unit_amount).toBe(100)
    expect(preview.items[0].variant_id).toBe('variant_1')
  })

  it('carries the provenance a report reads', async () => {
    const client = createTestClient()

    const [item] = (await client.pricePreview.create({ items: [{ variant_id: 'variant_1' }] }))
      .items

    expect(item.price_list_id).toBeNull()
    expect(item.price_source).toBeNull()
    expect(item.available_quantity).toBe(7)
  })
})
