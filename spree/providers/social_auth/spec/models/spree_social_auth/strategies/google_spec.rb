require 'spec_helper'

RSpec.describe SpreeSocialAuth::Strategies::Google do
  let(:store) { @default_store }
  let(:redirect_uri) { 'https://shop.example.com/account/callback/google' }
  let(:integration) do
    create_social_integration(
      integration_class: SpreeSocialAuth::Integrations::Google,
      client_id: 'google-client-id',
      client_secret: 'google-client-secret',
      redirect_uri: redirect_uri
    )
  end

  before { Spree::Current.store = store }

  def strategy(params: {}, integration: self.integration)
    described_class.new(params: params.with_indifferent_access, request_env: {}, provider: :google, integration: integration)
  end

  describe '.provider' do
    it 'reports how the login page should treat it' do
      provider = described_class.provider

      expect(provider.key).to eq(:google)
      expect(provider.kind).to eq(:redirect)
      expect(provider.requires_email).to be false
    end
  end

  describe '#authorization_url' do
    it 'asks Google for the standard claims' do
      url = strategy.authorization_url(state: 'state-1')

      expect(url).to start_with('https://accounts.google.com/o/oauth2/v2/auth?')
      expect(url).to include('client_id=google-client-id')
      expect(url).to include(CGI.escape('openid email profile'))
      expect(url).to include('state=state-1')
      expect(url).to include(CGI.escape(redirect_uri))
    end
  end

  describe '#callback' do
    it 'sends the code with the registered callback and reads the profile with a bearer token' do
      token_stub = stub_request(:post, SocialAuthSpecHelpers::GOOGLE_TOKEN_PATTERN).
                   with(body: { code: 'auth-code', client_id: 'google-client-id',
                                client_secret: 'google-client-secret',
                                redirect_uri: redirect_uri, grant_type: 'authorization_code' }).
                   to_return(status: 200, headers: SocialAuthSpecHelpers::JSON_HEADERS,
                             body: { access_token: 'google-access-token-1', expires_in: 3600 }.to_json)
      profile_stub = stub_request(:get, SocialAuthSpecHelpers::GOOGLE_PROFILE_PATTERN).
                     with(headers: { 'Authorization' => 'Bearer google-access-token-1' }).
                     to_return(status: 200, headers: SocialAuthSpecHelpers::JSON_HEADERS,
                               body: { sub: 'google-subject-1', email: 'ada@example.com', email_verified: true }.to_json)

      strategy(params: { code: 'auth-code' }).callback

      expect(token_stub).to have_been_requested
      expect(profile_stub).to have_been_requested
    end

    it 'signs in the shopper whose Google identity is already linked' do
      customer = create(:user)
      create(:user_identity, user: customer, provider: 'google', uid: 'google-subject-1')
      stub_google_exchange

      result = strategy(params: { code: 'auth-code', redirect_uri: redirect_uri }).callback

      expect(result.success?).to be true
      expect(result.value).to eq(customer)
    end

    # The point of a provider that returns a verified address: an existing
    # account adopts the identity instead of a second account appearing.
    it 'adopts an existing account whose address Google verified' do
      existing = create(:user, email: 'ada@example.com')
      stub_google_exchange

      expect do
        @result = strategy(params: { code: 'auth-code' }).callback
      end.not_to change(Spree.customer_class, :count)

      expect(@result.value).to eq(existing)
      expect(existing.identities.reload.count).to eq(1)
    end

    it 'refuses an address Google marks unverified' do
      create(:user, email: 'ada@example.com')
      stub_google_exchange(profile: { email_verified: false })

      result = strategy(params: { code: 'auth-code' }).callback

      expect(result.success?).to be false
      expect(result.error).to eq(Spree.t('errors.messages.email_taken'))
    end

    it 'registers a new account with the name Google returned, password-less' do
      stub_google_exchange

      expect do
        @result = strategy(params: { code: 'auth-code' }).callback
      end.to change(Spree.customer_class, :count).by(1)

      customer = @result.value
      expect(customer.email).to eq('ada@example.com')
      expect(customer.first_name).to eq('Ada')
      expect(customer.last_name).to eq('Lovelace')
      expect(customer.password_digest).to be_nil
    end

    it 'keys the identity on Google subject rather than the address' do
      stub_google_exchange

      strategy(params: { code: 'auth-code' }).callback

      identity = Spree::UserIdentity.find_for(provider: 'google', uid: 'google-subject-1')
      expect(identity).to be_present
      expect(identity.info).to include('name' => 'Ada Lovelace')
    end

    # Google refuses with a real HTTP status and a JSON error body.
    it 'surfaces a refusal Google sent with a status' do
      stub_google_token_error(status: 400, error: 'invalid_grant', description: 'Bad Request')

      result = strategy(params: { code: 'auth-code' }).callback

      expect(result.success?).to be false
      expect(result.error).to match(/refused the request \(HTTP 400/)
      expect(result.error).to match(/invalid_grant/)
    end

    it 'reports an unreachable provider as such' do
      stub_request(:post, SocialAuthSpecHelpers::GOOGLE_TOKEN_PATTERN).to_timeout

      result = strategy(params: { code: 'auth-code' }).callback

      expect(result.success?).to be false
      expect(result.error).to match(/could not be reached/)
    end
  end
end
