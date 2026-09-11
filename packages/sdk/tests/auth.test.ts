import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { isRegistrationRequired } from '../src'
import { createTestClient, TEST_BASE_URL } from './helpers'
import { server } from './mocks/server'

const API_PREFIX = `${TEST_BASE_URL}/api/v3/store`

describe('auth', () => {
  describe('login', () => {
    it('returns auth tokens on successful login', async () => {
      const client = createTestClient()
      const result = await client.auth.login({
        email: 'test@example.com',
        password: 'password123',
      })

      expect(result.token).toBe('test-jwt-token')
      expect(result.user.email).toBe('test@example.com')
    })

    it('throws SpreeError on invalid credentials', async () => {
      server.use(
        http.post(`${API_PREFIX}/auth/login`, () =>
          HttpResponse.json(
            { error: { code: 'unauthorized', message: 'Invalid credentials' } },
            { status: 401 },
          ),
        ),
      )

      const client = createTestClient()
      await expect(
        client.auth.login({ email: 'bad@example.com', password: 'wrong' }),
      ).rejects.toThrow('Invalid credentials')
    })
  })

  describe('register (via customers.create)', () => {
    it('returns auth tokens on successful registration', async () => {
      const client = createTestClient()
      const result = await client.customers.create({
        email: 'new@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        first_name: 'New',
        last_name: 'User',
      })

      expect(result.token).toBeDefined()
      expect(result.user).toBeDefined()
    })

    it('sends phone, accepts_email_marketing, and metadata', async () => {
      let capturedBody: Record<string, unknown> = {}
      server.use(
        http.post(`${API_PREFIX}/customers`, async ({ request }) => {
          capturedBody = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({
            token: 'test-jwt-token',
            user: { id: 'user_1', email: 'new@example.com', first_name: null, last_name: null },
          })
        }),
      )

      const client = createTestClient()
      await client.customers.create({
        email: 'new@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        phone: '+1234567890',
        accepts_email_marketing: true,
        metadata: { source: 'storefront' },
      })

      expect(capturedBody.phone).toBe('+1234567890')
      expect(capturedBody.accepts_email_marketing).toBe(true)
      expect(capturedBody.metadata).toEqual({ source: 'storefront' })
    })

    it('throws SpreeError on validation failure', async () => {
      server.use(
        http.post(`${API_PREFIX}/customers`, () =>
          HttpResponse.json(
            {
              error: {
                code: 'unprocessable_entity',
                message: 'Validation failed',
                details: { email: ['has already been taken'] },
              },
            },
            { status: 422 },
          ),
        ),
      )

      const client = createTestClient()
      try {
        await client.customers.create({
          email: 'existing@example.com',
          password: 'password123',
          password_confirmation: 'password123',
        })
        expect.unreachable('Should have thrown')
      } catch (error: any) {
        expect(error.code).toBe('unprocessable_entity')
        expect(error.status).toBe(422)
        expect(error.details?.email).toContain('has already been taken')
      }
    })
  })

  describe('refresh', () => {
    it('returns new access token and rotated refresh token', async () => {
      const client = createTestClient()
      const result = await client.auth.refresh({ refresh_token: 'rt_old' })

      expect(result.token).toBe('refreshed-jwt-token')
      expect(result.refresh_token).toBe('rt_refreshed')
    })
  })

  describe('logout', () => {
    it('revokes the refresh token', async () => {
      const client = createTestClient()
      await client.auth.logout({ refresh_token: 'rt_login' })
      // 204 No Content — no error means success
    })
  })

  describe('providers', () => {
    it('lists the password provider and the configured redirect providers', async () => {
      const client = createTestClient()
      const result = await client.auth.providers()

      expect(result.providers).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ key: 'email', kind: 'password' }),
          expect.objectContaining({ key: 'wechat', kind: 'redirect', requires_email: true }),
        ]),
      )
    })
  })

  describe('loginWithRedirect', () => {
    it('sends the code and state the provider returned, and signs the shopper in', async () => {
      let capturedBody: Record<string, unknown> = {}
      server.use(
        http.post(`${API_PREFIX}/auth/login`, async ({ request }) => {
          capturedBody = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({
            token: 'test-jwt-token',
            refresh_token: 'rt_login',
            user: { id: 'user_1', email: 'ada@example.com', first_name: 'Ada', last_name: null },
          })
        }),
      )

      const client = createTestClient()
      const result = await client.auth.loginWithRedirect({
        provider: 'google',
        code: 'auth-code',
        state: 'state-1',
        redirect_uri: 'https://shop.example.com/account/callback/google',
      })

      expect(capturedBody).toEqual({
        provider: 'google',
        code: 'auth-code',
        state: 'state-1',
        redirect_uri: 'https://shop.example.com/account/callback/google',
      })
      if (isRegistrationRequired(result)) throw new Error('expected tokens')
      expect(result.token).toBe('test-jwt-token')
    })

    // WeChat and Douyin return no email, so the account does not exist yet.
    it('reports a registration step when the provider returned no email', async () => {
      server.use(
        http.post(`${API_PREFIX}/auth/login`, () =>
          HttpResponse.json({ status: 'registration_required', registration_token: 'reg-token-1' }),
        ),
      )

      const client = createTestClient()
      const result = await client.auth.loginWithRedirect({
        provider: 'wechat',
        code: 'auth-code',
        state: 'state-1',
      })

      expect(isRegistrationRequired(result)).toBe(true)
      if (!isRegistrationRequired(result)) throw new Error('expected a registration step')
      expect(result.registration_token).toBe('reg-token-1')
    })
  })

  describe('completeRegistration', () => {
    it('creates the account with the supplied email and returns tokens', async () => {
      let capturedBody: Record<string, unknown> = {}
      server.use(
        http.post(`${API_PREFIX}/auth/complete`, async ({ request }) => {
          capturedBody = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(
            {
              token: 'test-jwt-token',
              refresh_token: 'rt_complete',
              user: { id: 'user_1', email: 'ada@example.com', first_name: 'Ada', last_name: null },
            },
            { status: 201 },
          )
        }),
      )

      const client = createTestClient()
      const result = await client.auth.completeRegistration({
        registration_token: 'reg-token-1',
        email: 'ada@example.com',
        terms_of_service: true,
      })

      expect(capturedBody).toEqual({
        registration_token: 'reg-token-1',
        email: 'ada@example.com',
        terms_of_service: true,
      })
      expect(result.token).toBe('test-jwt-token')
      expect(result.refresh_token).toBe('rt_complete')
    })

    it('throws SpreeError when the email already belongs to an account', async () => {
      server.use(
        http.post(`${API_PREFIX}/auth/complete`, () =>
          HttpResponse.json(
            {
              error: { code: 'email_taken', message: 'An account with this email already exists.' },
            },
            { status: 422 },
          ),
        ),
      )

      const client = createTestClient()

      await expect(
        client.auth.completeRegistration({
          registration_token: 'reg-token-1',
          email: 'ada@example.com',
        }),
      ).rejects.toThrow('An account with this email already exists.')
    })
  })
})
