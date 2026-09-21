import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { createTestClient, TEST_BASE_URL } from './helpers'
import { server } from './mocks/server'

const API_PREFIX = `${TEST_BASE_URL}/api/v3/store`

describe('cart selection', () => {
  it('writes the ticks over the lines it is given', async () => {
    let capturedBody: Record<string, unknown> = {}
    server.use(
      http.patch(`${API_PREFIX}/carts/cart_1/selection`, async ({ request }) => {
        capturedBody = (await request.json()) as Record<string, unknown>
        return HttpResponse.json({
          id: 'cart_1',
          number: 'R123456',
          total_quantity: 3,
          selected_quantity: 1,
          items: [
            { id: 'li_1', variant_id: 'var_1', quantity: 2, selected: false, total: '120.0' },
            { id: 'li_2', variant_id: 'var_2', quantity: 1, selected: true, total: '40.0' },
          ],
        })
      }),
    )

    const cart = await createTestClient().carts.selection.update('cart_1', {
      selected: false,
      line_item_ids: ['li_1'],
    })

    expect(capturedBody.selected).toBe(false)
    expect(capturedBody.line_item_ids).toEqual(['li_1'])
    expect(cart.selected_quantity).toBe(1)
    expect(cart.items?.[0].selected).toBe(false)
  })
  it('sends the promotion the shopper chose for a line', async () => {
    let capturedBody: Record<string, unknown> = {}
    server.use(
      http.post(`${API_PREFIX}/carts/cart_1/promotion_selection`, async ({ request }) => {
        capturedBody = (await request.json()) as Record<string, unknown>
        return HttpResponse.json({
          id: 'cart_1',
          number: 'R123456',
          items: [
            {
              id: 'li_1',
              variant_id: 'var_1',
              quantity: 2,
              promotion_id: 'promo_2',
              promotion_candidates: [
                { id: 'promo_1', name: 'Save 5', amount: '5.0' },
                { id: 'promo_2', name: 'Save 30', amount: '30.0' },
              ],
            },
          ],
        })
      }),
    )

    const cart = await createTestClient().carts.promotionSelection.create(
      'cart_1',
      { promotion_id: 'promo_2', line_item_id: 'li_1' },
      { token: 'user-jwt' },
    )

    expect(capturedBody.promotion_id).toBe('promo_2')
    expect(capturedBody.line_item_id).toBe('li_1')
    expect(cart.items?.[0].promotion_id).toBe('promo_2')
  })
})
