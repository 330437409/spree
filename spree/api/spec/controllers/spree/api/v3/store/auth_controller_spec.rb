require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::AuthController, type: :controller do
  render_views

  include_context 'API v3 Store'

  # A provider reached by a browser redirect, registered the way a real one is:
  # a factory carrying the per-registration settings that builds one strategy
  # per request. The registry reads kind/label/availability off the factory.
  let(:redirect_strategy_class) do
    Class.new(Spree::Authentication::Strategies::BaseStrategy) do
      def provider = 'wechat'

      def callback
        profile = Spree::Authentication::Profile.new(
          provider: 'wechat',
          uid: params[:code] == 'returning' ? 'openid-returning' : 'openid-new',
          info: { 'nickname' => 'Ada' }
        )
        resolution = resolve_account(profile)

        resolution.registration_required? ? registration_required(profile) : success(resolution.user)
      end
    end
  end

  let(:redirect_factory) do
    strategy = redirect_strategy_class

    Class.new do
      define_method(:build) do |params:, request_env:, user_class: nil|
        strategy.new(params: params, request_env: request_env, user_class: user_class)
      end

      def kind = :redirect
      def label = 'WeChat'
      def requires_email = true
      def available? = true
      def authorization_url(state:) = "https://open.weixin.qq.com/connect/qrconnect?state=#{state}"
    end.new
  end

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'POST #create (login)' do
    let!(:existing_user) { create(:user, password: 'password123', password_confirmation: 'password123') }

    it 'authenticates with email and password' do
      post :create, params: { provider: 'email', email: existing_user.email, password: 'password123' }

      expect(response).to have_http_status(:ok)
      expect(json_response['token']).to be_present
    end

    it 'returns a refresh token on login' do
      post :create, params: { provider: 'email', email: existing_user.email, password: 'password123' }

      expect(response).to have_http_status(:ok)
      expect(json_response['refresh_token']).to be_present
    end

    it 'creates a RefreshToken record' do
      expect {
        post :create, params: { provider: 'email', email: existing_user.email, password: 'password123' }
      }.to change(Spree::RefreshToken, :count).by(1)
    end

    it 'returns user data on successful login' do
      post :create, params: { provider: 'email', email: existing_user.email, password: 'password123' }

      expect(json_response['user']).to be_present
      expect(json_response['user']['email']).to eq(existing_user.email)
    end

    context 'invalid credentials' do
      it 'returns unauthorized for wrong password' do
        post :create, params: { provider: 'email', email: existing_user.email, password: 'wrong' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_failed')
      end

      it 'returns unauthorized for non-existent email' do
        post :create, params: { provider: 'email', email: 'nonexistent@example.com', password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_failed')
      end

      it 'returns unauthorized for missing email' do
        post :create, params: { provider: 'email', password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns unauthorized for missing password' do
        post :create, params: { provider: 'email', email: existing_user.email }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not create a RefreshToken on failure' do
        expect {
          post :create, params: { provider: 'email', email: existing_user.email, password: 'wrong' }
        }.not_to change(Spree::RefreshToken, :count)
      end
    end

    context 'without API key' do
      before { request.headers['X-Spree-Api-Key'] = nil }

      it 'returns unauthorized' do
        post :create, params: { provider: 'email', email: existing_user.email, password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with a custom identity provider' do
      let(:strategy_class) do
        Class.new(Spree::Authentication::Strategies::BaseStrategy) do
          def provider
            'external_idp'
          end

          def authenticate
            token = params[:token]
            return failure('invalid_token') if token != 'valid-jwt'

            user = find_or_create_user_from_oauth(
              provider: 'external_idp',
              uid:      'idp-user-1',
              info:     { email: 'sso@example.com', first_name: 'Alice' }
            )
            success(user)
          end
        end
      end

      around do |example|
        Spree.store_authentication_strategies.add(:external_idp, strategy_class)
        example.run
      ensure
        Spree.store_authentication_strategies.remove(:external_idp)
      end

      it 'dispatches to the registered strategy and returns a Spree JWT' do
        post :create, params: { provider: 'external_idp', token: 'valid-jwt' }

        expect(response).to have_http_status(:ok)
        expect(json_response['token']).to be_present
        expect(json_response['refresh_token']).to be_present
        expect(json_response['user']['email']).to eq('sso@example.com')
      end

      it 'creates a UserIdentity mapping on first login' do
        expect {
          post :create, params: { provider: 'external_idp', token: 'valid-jwt' }
        }.to change(Spree::UserIdentity, :count).by(1)

        identity = Spree::UserIdentity.last
        expect(identity.provider).to eq('external_idp')
        expect(identity.uid).to eq('idp-user-1')
      end

      it 'reuses the existing user on subsequent logins' do
        post :create, params: { provider: 'external_idp', token: 'valid-jwt' }
        first_user_id = json_response['user']['id']

        expect {
          post :create, params: { provider: 'external_idp', token: 'valid-jwt' }
        }.not_to change(Spree.customer_class, :count)

        expect(json_response['user']['id']).to eq(first_user_id)
      end

      it 'returns unauthorized when the strategy fails' do
        post :create, params: { provider: 'external_idp', token: 'bad-jwt' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_failed')
        expect(json_response['error']['message']).to eq('invalid_token')
      end

      it 'does not create a RefreshToken when the strategy fails' do
        expect {
          post :create, params: { provider: 'external_idp', token: 'bad-jwt' }
        }.not_to change(Spree::RefreshToken, :count)
      end
    end

    context 'with an unregistered provider' do
      it 'returns bad_request' do
        post :create, params: { provider: 'nope', token: 'whatever' }

        expect(response).to have_http_status(:bad_request)
        expect(json_response['error']['code']).to eq('invalid_provider')
      end
    end
  end

  describe 'POST #refresh' do
    let!(:existing_user) { create(:user, password: 'password123', password_confirmation: 'password123') }
    let!(:refresh_token) { create(:refresh_token, user: existing_user) }

    it 'returns a new access token and rotated refresh token' do
      post :refresh, params: { refresh_token: refresh_token.token }

      expect(response).to have_http_status(:ok)
      expect(json_response['token']).to be_present
      expect(json_response['refresh_token']).to be_present
      # Refresh token should be rotated (different from original)
      expect(json_response['refresh_token']).not_to eq(refresh_token.token)
    end

    it 'returns user data' do
      post :refresh, params: { refresh_token: refresh_token.token }

      expect(json_response['user']).to be_present
      expect(json_response['user']['email']).to eq(existing_user.email)
    end

    it 'destroys the old refresh token' do
      post :refresh, params: { refresh_token: refresh_token.token }

      expect(Spree::RefreshToken.find_by(id: refresh_token.id)).to be_nil
    end

    it 'creates a new refresh token' do
      expect {
        post :refresh, params: { refresh_token: refresh_token.token }
      }.not_to change(Spree::RefreshToken, :count) # one destroyed, one created
    end

    context 'without refresh_token param' do
      it 'returns unauthorized' do
        post :refresh

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('invalid_refresh_token')
      end
    end

    context 'with invalid refresh token' do
      it 'returns unauthorized' do
        post :refresh, params: { refresh_token: 'invalid_token' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('invalid_refresh_token')
      end
    end

    context 'with expired refresh token' do
      before { refresh_token.update_column(:expires_at, 1.day.ago) }

      it 'returns unauthorized' do
        post :refresh, params: { refresh_token: refresh_token.token }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('invalid_refresh_token')
      end
    end
  end

  describe 'POST #logout' do
    let!(:existing_user) { create(:user, password: 'password123', password_confirmation: 'password123') }
    let!(:refresh_token) { create(:refresh_token, user: existing_user) }

    it 'revokes the refresh token' do
      expect {
        post :logout, params: { refresh_token: refresh_token.token }
      }.to change(Spree::RefreshToken, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'works without an access token (the refresh token is the credential)' do
      expect {
        post :logout, params: { refresh_token: refresh_token.token }
      }.to change(Spree::RefreshToken, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'succeeds even with invalid refresh token' do
      post :logout, params: { refresh_token: 'nonexistent' }

      expect(response).to have_http_status(:no_content)
    end

    it 'leaves a token minted for another surface alone' do
      admin_token = create(:refresh_token, :for_admin)

      expect {
        post :logout, params: { refresh_token: admin_token.token }
      }.not_to change(Spree::RefreshToken, :count)

      expect(response).to have_http_status(:no_content)
      expect(admin_token.reload).to be_present
    end

    it 'succeeds without refresh token param' do
      post :logout

      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'GET #providers' do
    before { Spree.store_authentication_strategies.add(:wechat, redirect_factory) }
    after { Spree.store_authentication_strategies.remove(:wechat) }

    it 'lists the password provider and the configured redirect provider' do
      get :providers

      expect(response).to have_http_status(:ok)

      providers = json_response['providers']
      expect(providers).to include({ 'key' => 'email', 'kind' => 'password' })

      wechat = providers.find { |provider| provider['key'] == 'wechat' }
      expect(wechat['kind']).to eq('redirect')
      expect(wechat['label']).to eq('WeChat')
      expect(wechat['requires_email']).to be true
      expect(wechat['authorization_url']).to include('state=')
    end

    # A provider whose integration is missing or inactive must not appear: a
    # button that can only fail is worse than no button.
    it 'leaves out a provider this store has not configured' do
      unavailable = Class.new do
        def kind = :redirect
        def label = 'Douyin'
        def available? = false
        def authorization_url(state:) = "https://open.douyin.com/platform/oauth/connect?state=#{state}"
      end.new
      Spree.store_authentication_strategies.add(:douyin, unavailable)

      get :providers

      expect(json_response['providers'].map { |provider| provider['key'] }).not_to include('douyin')
    ensure
      Spree.store_authentication_strategies.remove(:douyin)
    end
  end

  describe 'POST #create with a redirect provider' do
    before do
      Spree.store_authentication_strategies.add(:wechat, redirect_factory)
      create(:allowed_origin, store: store, origin: 'https://shop.example.com')
    end

    after { Spree.store_authentication_strategies.remove(:wechat) }

    let(:state) do
      payload = { provider: 'wechat', nonce: SecureRandom.hex(8), store_id: store.id }
      Rails.application.message_verifier('spree/store/oauth_state').generate(payload, expires_in: 15.minutes)
    end

    let(:login_params) do
      {
        provider: 'wechat',
        code: 'returning',
        state: state,
        redirect_uri: 'https://shop.example.com/account/callback/wechat'
      }
    end

    it 'signs a returning shopper in' do
      customer = create(:user)
      create(:user_identity, user: customer, provider: 'wechat', uid: 'openid-returning')

      post :create, params: login_params

      expect(response).to have_http_status(:ok)
      expect(json_response['token']).to be_present
      expect(json_response['refresh_token']).to be_present
      expect(json_response['user']['email']).to eq(customer.email)
    end

    # The provider authenticated the shopper but returned no email, so no
    # account exists yet — and none is invented.
    it 'asks for an email rather than creating an account without one' do
      expect { post :create, params: login_params.merge(code: 'new') }
        .not_to change(Spree.customer_class, :count)

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('registration_required')
      expect(json_response['registration_token']).to be_present
    end

    it 'rejects a state minted for another store' do
      other_store = create(:store)
      payload = { provider: 'wechat', nonce: SecureRandom.hex(8), store_id: other_store.id }
      foreign_state = Rails.application.message_verifier('spree/store/oauth_state')
                                             .generate(payload, expires_in: 15.minutes)

      expect { post :create, params: login_params.merge(state: foreign_state) }
        .not_to change(Spree.customer_class, :count)

      expect(response).to have_http_status(:bad_request)
      expect(json_response['error']['code']).to eq('invalid_oauth_state')
    end

    it 'rejects a forged state' do
      post :create, params: login_params.merge(state: 'forged')

      expect(response).to have_http_status(:bad_request)
      expect(json_response['error']['code']).to eq('invalid_oauth_state')
    end

    it 'rejects a redirect_uri outside the store origins' do
      post :create, params: login_params.merge(redirect_uri: 'https://evil.example.com/callback')

      expect(response).to have_http_status(:bad_request)
      expect(json_response['error']['code']).to eq('redirect_url_not_allowed')
    end
  end

  describe 'POST #complete' do
    before do
      Spree.store_authentication_strategies.add(:wechat, Spree::Authentication::Strategies::EmailPasswordStrategy)
    end

    after { Spree.store_authentication_strategies.remove(:wechat) }

    def registration_token(store:, provider: 'wechat', uid: 'openid-1')
      payload = Spree::Authentication::Profile.new(
        provider: provider, uid: uid, info: { 'first_name' => 'Ada' }
      ).to_h
      payload[:store_id] = store.id

      Rails.application.message_verifier('spree/store/social_signup').generate(payload, expires_in: 15.minutes)
    end

    it 'registers the account, links the identity and signs the shopper in' do
      expect do
        post :complete, params: {
          registration_token: registration_token(store: store),
          email: 'ada@example.com',
          terms_of_service: true
        }
      end.to change(Spree.customer_class, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['token']).to be_present
      expect(json_response['user']['email']).to eq('ada@example.com')
      expect(Spree::UserIdentity.find_for(provider: 'wechat', uid: 'openid-1')).to be_present
    end

    it 'refuses a token minted for another store' do
      post :complete, params: {
        registration_token: registration_token(store: create(:store)),
        email: 'ada@example.com'
      }

      expect(response).to have_http_status(:unauthorized)
      expect(json_response['error']['code']).to eq('invalid_registration_token')
    end

    it 'refuses a forged token' do
      post :complete, params: { registration_token: 'forged', email: 'ada@example.com' }

      expect(response).to have_http_status(:unauthorized)
      expect(json_response['error']['code']).to eq('invalid_registration_token')
    end

    it 'reports an address that already belongs to an account' do
      create(:user, email: 'ada@example.com')

      post :complete, params: {
        registration_token: registration_token(store: store),
        email: 'ada@example.com'
      }

      expect(response).to have_http_status(422)
      expect(json_response['error']['code']).to eq('email_taken')
    end
  end
end
