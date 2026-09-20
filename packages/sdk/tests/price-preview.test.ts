import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { createTestClient, TEST_BASE_URL } from './helpers'
import { server } from './mocks/server'

const API_PREFIX = `${TEST_BASE_URL}/api/v3/store`

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

  // The area page's own question travels as request parameters: which shop it
  // is about, and the context a registered source prices by.
  it('sends the warehouse and the source context it was given', async () => {
    let capturedBody: Record<string, unknown> = {}
    server.use(
      http.post(`${API_PREFIX}/price_preview`, async ({ request }) => {
        capturedBody = (await request.json()) as Record<string, unknown>
        return HttpResponse.json({
          currency: 'USD',
          total: 120,
          quantity: 2,
          purchasable: true,
          flags: { flash_sale_id: 'fsale_1' },
          items: [
            {
              variant_id: 'variant_1',
              product_id: 'prod_1',
              quantity: 2,
              unit_amount: 60,
              compare_at_amount: 100,
              total: 120,
              price_list_id: null,
              price_ends_at: '2026-09-20T12:00:00Z',
              price_source: null,
              source: 'flash_sale',
              in_stock: true,
              backorderable: false,
              purchasable: true,
              available_quantity: 7,
              stock_location_quantity: 3,
            },
          ],
        })
      }),
    )

    const client = createTestClient()
    const preview = await client.pricePreview.create({
      stock_location_id: 'sloc_1',
      context: { flash_sale_id: 'fsale_1' },
      items: [{ variant_id: 'variant_1', quantity: 2 }],
    })

    expect(capturedBody.stock_location_id).toBe('sloc_1')
    expect(capturedBody.context).toEqual({ flash_sale_id: 'fsale_1' })
    expect(preview.items[0].stock_location_quantity).toBe(3)
    expect(preview.items[0].price_ends_at).toBe('2026-09-20T12:00:00Z')
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
