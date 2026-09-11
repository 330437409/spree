# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Authentication API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:existing_user) { create(:user, email: 'test@example.com', password: 'password123') }

  # A redirect provider whose profile carries no email — the shape the Chinese
  # providers return, and the reason the registration step exists.
  let(:wechat_factory) do
    Class.new do
      def build(params:, request_env:, user_class: nil)
        Spree::Authentication::Strategies::EmailPasswordStrategy.new(
          params: params, request_env: request_env, user_class: user_class
        )
      end

      def kind = :redirect
      def label = 'WeChat'
      def requires_email = true
      def available? = true
      def authorization_url(state:) = "https://open.weixin.qq.com/connect/qrconnect?state=#{state}"
    end.new
  end

  # The token POST /auth/login hands back when a provider returned no email.
  def social_registration_token(uid:, provider: 'wechat')
    payload = Spree::Authentication::Profile.new(provider: provider, uid: uid, info: { 'first_name' => 'Ada' }).to_h
    payload[:store_id] = store.id

    Rails.application.message_verifier('spree/store/social_signup').generate(payload, expires_in: 15.minutes)
  end

  path '/api/v3/store/auth/login' do
    post 'Login' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        Authenticates a customer and returns a JWT access token + refresh token.

        The `provider` field selects the authentication method. When omitted it
        defaults to `email`, the built-in email/password login.

        To authenticate against a third-party identity provider (Auth0, Okta,
        Firebase, a custom JWT issuer, SAML, etc.), send
        `{ "provider": "<your_key>", ... }` with the fields that provider
        requires. The endpoint returns the same JWT + refresh token regardless of
        which provider authenticated the request. See
        [Custom API Authentication](https://spreecommerce.org/docs/developer/how-to/custom-api-authentication)
        for the list of configured providers and their required fields.
      DESC

      sdk_example 'auth/login'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        oneOf: [
          {
            title: 'EmailPasswordLogin',
            description: 'Built-in email/password authentication (default when `provider` is omitted).',
            type: :object,
            properties: {
              provider: { type: :string, enum: ['email'], default: 'email' },
              email: { type: :string, format: 'email', example: 'customer@example.com' },
              password: { type: :string, example: 'password123' }
            },
            required: %w[email password]
          },
          {
            title: 'ProviderLogin',
            description: <<~D,
              Provider-dispatched login. The `provider` key selects a configured
              authentication provider; the remaining fields are forwarded to it.
              Required fields depend on the provider — see
              [Custom API Authentication](https://spreecommerce.org/docs/developer/how-to/custom-api-authentication).
            D
            type: :object,
            properties: {
              provider: {
                type: :string,
                example: 'auth0',
                description: 'Registered provider key (anything other than `email`).',
                not: { enum: ['email'] }
              }
            },
            required: %w[provider],
            additionalProperties: true
          }
        ]
      }

      response '200', 'login successful' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { email: existing_user.email, password: 'password123' } }

        schema '$ref' => '#/components/schemas/AuthResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
          expect(data['user']).to be_present
          expect(data['user']['email']).to eq(existing_user.email)
        end
      end

      response '401', 'invalid credentials' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { email: existing_user.email, password: 'wrong_password' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '401', 'user not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { email: 'nonexistent@example.com', password: 'password123' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '401', 'missing API key' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:body) { { email: existing_user.email, password: 'password123' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/auth/refresh' do
    post 'Refresh token' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      description 'Exchanges a refresh token for a new access JWT and rotated refresh token. No Authorization header needed.'

      sdk_example 'auth/refresh'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          refresh_token: { type: :string, description: 'Refresh token from login response' }
        },
        required: %w[refresh_token]
      }

      response '200', 'token refreshed' do
        let(:'x-spree-api-key') { api_key.token }
        let(:refresh_token_record) { create(:refresh_token, user: existing_user) }
        let(:body) { { refresh_token: refresh_token_record.token } }

        schema '$ref' => '#/components/schemas/AuthResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
          expect(data['refresh_token']).to be_present
          expect(data['user']).to be_present
        end
      end

      response '401', 'missing or invalid refresh token' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { refresh_token: 'invalid_token' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/auth/logout' do
    post 'Logout' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      description 'Revokes the submitted refresh token. The refresh token itself is the credential — no Authorization header is required, so a client with an expired access JWT can still log out.'

      sdk_example 'auth/logout'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          refresh_token: { type: :string, description: 'Refresh token to revoke' }
        }
      }

      response '204', 'logout successful' do
        let(:'x-spree-api-key') { api_key.token }
        let(:refresh_token_record) { create(:refresh_token, user: existing_user) }
        let(:body) { { refresh_token: refresh_token_record.token } }

        run_test! do
          expect(Spree::RefreshToken.find_by(token: refresh_token_record.token)).to be_nil
        end
      end

      response '204', 'logout without refresh token (no-op)' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { {} }

        run_test!
      end
    end
  end

  path '/api/v3/store/auth/providers' do
    get 'List authentication providers' do
      tags 'Authentication'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        Lists the authentication providers this store has configured, for a
        storefront to render its login page: the password form when `email` is
        registered, a button per redirect provider.

        A redirect provider's `authorization_url` already carries a signed
        `state`; the storefront stores it and sends it back with the
        authorization code. `requires_email` warns that the provider cannot
        return an email, so the shopper will be asked for one before the
        account is created.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true

      response '200', 'providers listed' do
        let(:'x-spree-api-key') { api_key.token }

        before { Spree.store_authentication_strategies.add(:wechat, wechat_factory) }
        after { Spree.store_authentication_strategies.remove(:wechat) }

        schema type: :object, properties: {
          providers: {
            type: :array,
            items: {
              type: :object,
              properties: {
                key: { type: :string, example: 'wechat' },
                kind: { type: :string, enum: %w[password redirect] },
                label: { type: :string, nullable: true, example: 'WeChat' },
                requires_email: { type: :boolean },
                authorization_url: { type: :string, nullable: true }
              },
              required: %w[key kind]
            }
          }
        }, required: %w[providers]

        run_test! do |response|
          data = JSON.parse(response.body)

          expect(data['providers']).to include(hash_including('key' => 'email', 'kind' => 'password'))
          expect(data['providers']).to include(
            hash_including('key' => 'wechat', 'kind' => 'redirect', 'requires_email' => true)
          )
        end
      end
    end
  end

  path '/api/v3/store/auth/complete' do
    post 'Complete a social registration' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        Finishes a login a provider could not finish on its own.

        Some providers (WeChat, Douyin, QQ, Weibo, Alipay) authenticate the
        shopper without returning an email. Nothing is created at that point:
        `POST /auth/login` answers `registration_required` with a short-lived
        signed `registration_token` instead. Send that token back with the
        shopper's email to create the account — password-less, claimed later
        through password reset — and receive the same JWT + refresh token pair
        as any other login.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          registration_token: { type: :string, description: 'Token from the `registration_required` login response' },
          email: { type: :string, format: 'email', example: 'customer@example.com' },
          first_name: { type: :string },
          last_name: { type: :string },
          terms_of_service: { type: :boolean, description: 'Whether the shopper ticked the terms box' }
        },
        required: %w[registration_token email]
      }

      response '201', 'account registered and signed in' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) do
          {
            registration_token: social_registration_token(uid: 'openid-1'),
            email: 'social-customer@example.com',
            terms_of_service: true
          }
        end

        before { Spree.store_authentication_strategies.add(:wechat, wechat_factory) }
        after { Spree.store_authentication_strategies.remove(:wechat) }

        schema '$ref' => '#/components/schemas/AuthResponse'

        run_test! do |response|
          data = JSON.parse(response.body)

          expect(data['token']).to be_present
          expect(data['refresh_token']).to be_present
          expect(data['user']['email']).to eq('social-customer@example.com')
        end
      end

      response '401', 'invalid or expired registration token' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { registration_token: 'forged', email: 'social-customer@example.com' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '422', 'email already belongs to an account' do
        let(:'x-spree-api-key') { api_key.token }
        let!(:taken) { create(:user, email: 'social-customer@example.com') }
        let(:body) do
          {
            registration_token: social_registration_token(uid: 'openid-2'),
            email: 'social-customer@example.com'
          }
        end

        before { Spree.store_authentication_strategies.add(:wechat, wechat_factory) }
        after { Spree.store_authentication_strategies.remove(:wechat) }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
