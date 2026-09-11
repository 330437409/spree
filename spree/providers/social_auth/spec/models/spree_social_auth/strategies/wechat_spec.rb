require 'spec_helper'

RSpec.describe SpreeSocialAuth::Strategies::WeChat do
  let(:store) { @default_store }
  let(:redirect_uri) { 'https://shop.example.com/account/callback/wechat' }
  let(:integration) { create_social_integration(store: store, redirect_uri: redirect_uri) }

  before { Spree::Current.store = store }

  def strategy(params: {}, integration: self.integration)
    described_class.new(params: params.with_indifferent_access, request_env: {}, provider: :wechat, integration: integration)
  end

  describe '#authorization_url' do
    it 'sends the shopper to WeChat with the store app and the registered callback' do
      url = strategy.authorization_url(state: 'state-1')

      expect(url).to start_with('https://open.weixin.qq.com/connect/qrconnect?')
      expect(url).to include('response_type=code')
      expect(url).to include('scope=snsapi_login')
      expect(url).to end_with('#wechat_redirect')
    end
  end

  describe '#callback' do
    it 'signs in the shopper whose WeChat identity is already linked' do
      customer = create(:user)
      create(:user_identity, user: customer, provider: 'wechat', uid: 'unionid-1')
      stub_wechat_exchange(profile: { 'unionid' => 'unionid-1' })

      result = strategy(params: { code: 'auth-code', redirect_uri: redirect_uri }).callback

      expect(result.success?).to be true
      expect(result.value).to eq(customer)
    end

    it 'refreshes the stored profile and tokens' do
      customer = create(:user)
      identity = create(:user_identity, user: customer, provider: 'wechat', uid: 'unionid-1')
      stub_wechat_exchange(profile: { 'unionid' => 'unionid-1' })

      strategy(params: { code: 'auth-code', redirect_uri: redirect_uri }).callback

      identity.reload
      expect(identity.access_token).to eq('access-token-1')
      expect(identity.refresh_token).to eq('refresh-token-1')
      expect(identity.info).to include('nickname' => 'Ada', 'unionid' => 'unionid-1')
      expect(identity.expires_at).to be_within(5.seconds).of(2.hours.from_now)
    end

    # A unionid is the only key that means the same person across the apps bound
    # to one Open Platform account; an openid only means something in this app.
    it 'identifies the shopper by unionid when WeChat returns one' do
      customer = create(:user)
      create(:user_identity, user: customer, provider: 'wechat', uid: 'unionid-1')
      stub_wechat_exchange(profile: { 'openid' => 'openid-1', 'unionid' => 'unionid-1' })

      result = strategy(params: { code: 'auth-code' }).callback

      expect(result.value).to eq(customer)
    end

    it 'falls back to the openid when there is no unionid' do
      stub_wechat_exchange(profile: { 'openid' => 'openid-9' })
      subject = strategy(params: { code: 'auth-code' })

      result = subject.callback

      expect(result.success?).to be false
      expect(subject.registration_required?).to be true
      expect(subject.registration_profile.uid).to eq('openid-9')
    end

    # WeChat returns no email, so there is nothing to create an account from —
    # the storefront asks for one instead.
    it 'asks for a registration rather than inventing an address' do
      stub_wechat_exchange
      subject = strategy(params: { code: 'auth-code', redirect_uri: redirect_uri })

      expect { subject.callback }.not_to change(Spree.customer_class, :count)
      expect(subject.registration_required?).to be true
      expect(subject.registration_profile.email).to be_nil
    end

    it 'refuses a callback URL that is not the registered one' do
      result = strategy(params: { code: 'auth-code', redirect_uri: 'https://evil.example.com/callback' }).callback

      expect(result.success?).to be false
      expect(result.error).to eq(Spree.t('spree_social_auth.errors.redirect_uri_mismatch'))
    end

    it 'refuses a callback without a code' do
      result = strategy(params: {}).callback

      expect(result.success?).to be false
      expect(result.error).to eq(Spree.t('spree_social_auth.errors.missing_code'))
    end

    it 'refuses when the provider is not configured for this store' do
      result = strategy(params: { code: 'auth-code' }, integration: nil).callback

      expect(result.success?).to be false
      expect(result.error).to eq(Spree.t('spree_social_auth.errors.provider_unavailable'))
    end

    # WeChat refuses with HTTP 200 and an errcode in the body, so a client that
    # trusted the status would read this as a successful sign-in.
    it 'explains rejected application credentials' do
      stub_wechat_token_error(code: 40013, message: 'invalid appid')

      result = strategy(params: { code: 'auth-code' }).callback

      expect(result.success?).to be false
      expect(result.error).to match(/rejected the application credentials/)
      expect(result.error).to match(/invalid appid/)
    end

    it 'tells the shopper to start again when the code has expired' do
      stub_wechat_token_error(code: 40029, message: 'invalid code')

      result = strategy(params: { code: 'auth-code' }).callback

      expect(result.success?).to be false
      expect(result.error).to match(/no longer usable/)
    end

    it 'reports an unreachable provider as such, not as a failed sign-in' do
      stub_request(:get, SocialAuthSpecHelpers::WECHAT_TOKEN_PATTERN).to_timeout

      result = strategy(params: { code: 'auth-code' }).callback

      expect(result.success?).to be false
      expect(result.error).to match(/could not be reached/)
    end
  end
end
