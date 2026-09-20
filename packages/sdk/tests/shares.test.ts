import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { createTestClient, TEST_BASE_URL } from './helpers'
import { server } from './mocks/server'

const API_PREFIX = `${TEST_BASE_URL}/api/v3/store`

describe('shares', () => {
  it('composes the card for the thing it names', async () => {
    const client = createTestClient()

    const share = await client.shares.create({ target_type: 'product', target_id: 'prod_1' })

    expect(share.title).toBe('青花瓷茶具')
    expect(share.path).toContain('type=inviteGoods')
    expect(share.qrcode_url).toBeNull()
  })

  it('sends the target and the context it was given', async () => {
    let capturedBody: Record<string, unknown> = {}
    server.use(
      http.post(`${API_PREFIX}/shares`, async ({ request }) => {
        capturedBody = (await request.json()) as Record<string, unknown>
        return HttpResponse.json({
          title: '青花瓷茶具',
          subtitle: null,
          image_url: null,
          path: '/pages/index?type=inviteGoods&typeId=id-prod%5F1',
          scene: null,
          qrcode_url: null,
          poster_url: null,
        })
      }),
    )

    await createTestClient().shares.create({
      target_type: 'invitation',
      target_id: 'inv_1',
      context: { binding: 'abc' },
    })

    expect(capturedBody.target_type).toBe('invitation')
    expect(capturedBody.target_id).toBe('inv_1')
    expect(capturedBody.context).toEqual({ binding: 'abc' })
  })
})
