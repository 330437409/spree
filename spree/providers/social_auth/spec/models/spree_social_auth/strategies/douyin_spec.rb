require 'spec_helper'

RSpec.describe SpreeSocialAuth::Strategies::Douyin do
  let(:store) { @default_store }
  let(:redirect_uri) { 'https://shop.example.com/account/callback/douyin' }
  let(:integration) do
    create_social_integration(
      integration_class: SpreeSocialAuth::Integrations::Douyin,
      client_id: 'dy_key',
      client_secret: 'dy_secret',
      redirect_uri: redirect_uri
    )
  end

  before { Spree::Current.store = store }

  def strategy(params: {}, integration: self.integration)
    described_class.new(params: params.with_indifferent_access, request_env: {}, provider: :douyin, integration: integration)
  end

  describe '.provider' do
    it 'reports how the login page should treat it' do
      provider = described_class.provider

      expect(provider.key).to eq(:douyin)
      expect(provider.kind).to eq(:redirect)
      expect(provider.requires_email).to be true
    end
  end

  describe '#authorization_url' do
    it 'sends the shopper to Douyin with the client key and the registered callback' do
      url = strategy.authorization_url(state: 'state-1')

      expect(url).to start_with('https://open.douyin.com/platform/oauth/connect?')
      expect(url).to include('client_key=dy_key')
      expect(url).to include('response_type=code')
      expect(url).to include('scope=user_info')
      expect(url).to include('state=state-1')
      expect(url).to include(CGI.escape(redirect_uri))
    end
  end

  describe '#callback' do
    it 'signs in the shopper whose Douyin identity is already linked' do
      customer = create(:user)
      create(:user_identity, user: customer, provider: 'douyin', uid: 'union-id-1')
      stub_douyin_exchange(profile: { 'union_id' => 'union-id-1' })

      result = strategy(params: { code: 'auth-code', redirect_uri: redirect_uri }).callback

      expect(result.success?).to be true
      expect(result.value).to eq(customer)
    end

    # Both calls are form posts, and the profile read needs the open_id the
    # token response carried.
    it 'posts the code as a form and reads the profile with the returned open_id' do
      customer = create(:user)
      create(:user_identity, user: customer, provider: 'douyin', uid: 'union-id-1')

      token_stub = stub_request(:post, SocialAuthSpecHelpers::DOUYIN_TOKEN_PATTERN).
                   with(body: { client_key: 'dy_key', client_secret: 'dy_secret', code: 'auth-code', grant_type: 'authorization_code' }).
                   to_return(
                     status: 200,
                     headers: SocialAuthSpecHelpers::JSON_HEADERS,
                     body: { data: { access_token: 'dy-access-token-1', open_id: 'open-id-1', error_code: 0 }, message: 'success' }.to_json
                   )
      profile_stub = stub_request(:post, SocialAuthSpecHelpers::DOUYIN_PROFILE_PATTERN).
                     with(body: { access_token: 'dy-access-token-1', open_id: 'open-id-1' }).
                     to_return(
                       status: 200,
                       headers: SocialAuthSpecHelpers::JSON_HEADERS,
                       body: { data: { open_id: 'open-id-1', union_id: 'union-id-1', nickname: 'Ada' }, err_no: 0 }.to_json
                     )

      result = strategy(params: { code: 'auth-code' }).callback

      expect(result.success?).to be true
      expect(token_stub).to have_been_requested
      expect(profile_stub).to have_been_requested
    end

    it 'refreshes the stored profile and tokens' do
      customer = create(:user)
      identity = create(:user_identity, user: customer, provider: 'douyin', uid: 'union-id-1')
      stub_douyin_exchange(profile: { 'union_id' => 'union-id-1' })

      strategy(params: { code: 'auth-code' }).callback

      identity.reload
      expect(identity.access_token).to eq('dy-access-token-1')
      expect(identity.refresh_token).to eq('dy-refresh-token-1')
      expect(identity.info).to include('nickname' => 'Ada', 'unionid' => 'union-id-1')
      expect(identity.expires_at).to be_within(5.seconds).of(15.days.from_now)
    end

    # A union_id means the same person across every app under one developer
    # account; an open_id only means something inside this app.
    it 'identifies the shopper by union_id when Douyin returns one' do
      customer = create(:user)
      create(:user_identity, user: customer, provider: 'douyin', uid: 'union-id-1')
      stub_douyin_exchange(profile: { 'open_id' => 'open-id-1', 'union_id' => 'union-id-1' })

      expect(strategy(params: { code: 'auth-code' }).callback.value).to eq(customer)
    end

    it 'falls back to the open_id, and asks for an email' do
      stub_douyin_exchange(profile: { 'open_id' => 'open-id-9' })
      subject = strategy(params: { code: 'auth-code' })

      result = subject.callback

      expect(result.success?).to be false
      expect(subject.registration_required?).to be true
      expect(subject.registration_profile.uid).to eq('open-id-9')
      expect(subject.registration_profile.email).to be_nil
    end

    it 'explains rejected application credentials' do
      stub_douyin_token_error(code: 10013, message: 'invalid client_key')

      result = strategy(params: { code: 'auth-code' }).callback

      expect(result.success?).to be false
      expect(result.error).to match(/rejected the application credentials/)
      expect(result.error).to match(/invalid client_key/)
    end

    it 'tells the shopper to start again when the code has expired' do
      stub_douyin_token_error(code: 10007, message: 'authorization code expired')

      result = strategy(params: { code: 'auth-code' }).callback

      expect(result.success?).to be false
      expect(result.error).to match(/no longer usable/)
    end

    # The profile endpoint carries its refusal in `err_no`, beside `data`.
    it 'reads a refusal from the profile envelope' do
      stub_douyin_exchange(profile: { 'union_id' => 'union-id-1' })
      stub_douyin_profile_error(code: 28001008, message: 'token expired')

      result = strategy(params: { code: 'auth-code' }).callback

      expect(result.success?).to be false
      expect(result.error).to match(/no longer valid/)
    end

    it 'refuses a callback URL that is not the registered one' do
      result = strategy(params: { code: 'auth-code', redirect_uri: 'https://evil.example.com/callback' }).callback

      expect(result.success?).to be false
      expect(result.error).to eq(Spree.t('spree_social_auth.errors.redirect_uri_mismatch'))
    end

    it 'reports an unreachable provider as such' do
      stub_request(:post, SocialAuthSpecHelpers::DOUYIN_TOKEN_PATTERN).to_timeout

      result = strategy(params: { code: 'auth-code' }).callback

      expect(result.success?).to be false
      expect(result.error).to match(/could not be reached/)
    end
  end
end
