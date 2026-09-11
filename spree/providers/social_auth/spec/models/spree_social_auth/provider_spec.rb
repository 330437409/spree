require 'spec_helper'

RSpec.describe SpreeSocialAuth::Provider do
  let(:store) { @default_store }
  let(:provider) { SpreeSocialAuth::Strategies::WeChat.provider }

  before { Spree::Current.store = store }

  it 'reports how the login page should treat it' do
    expect(provider.kind).to eq(:redirect)
    expect(provider.label).to eq('WeChat')
    expect(provider.requires_email).to be true
  end

  it 'is unavailable until the store has an active integration' do
    expect(provider.available?).to be false

    create_social_integration(store: store)

    expect(provider.available?).to be true
  end

  it 'is unavailable when the store integration is inactive' do
    create_social_integration(store: store, active: false)

    expect(provider.available?).to be false
  end

  it 'builds the authorization URL from the store credentials' do
    create_social_integration(
      store: store,
      client_id: 'wx_appid',
      redirect_uri: 'https://shop.example.com/account/callback/wechat'
    )

    url = provider.authorization_url(state: 'state-1')

    expect(url).to start_with('https://open.weixin.qq.com/connect/qrconnect?')
    expect(url).to include('appid=wx_appid')
    expect(url).to include('scope=snsapi_login')
    expect(url).to include('state=state-1')
    expect(url).to include(CGI.escape('https://shop.example.com/account/callback/wechat'))
    expect(url).to end_with('#wechat_redirect')
  end

  it 'builds a strategy carrying the provider key and the store integration' do
    integration = create_social_integration(store: store)

    strategy = provider.build(params: { code: 'abc' }, request_env: {})

    expect(strategy.provider).to eq(:wechat)
    expect(strategy.integration).to eq(integration)
  end

  # The factory lives for the whole process, so it must read the current
  # request's integrations every time — a memoized one would sign one store's
  # shoppers in with another store's app.
  it 'reads the store integrations per call rather than once' do
    store_a = create(:store)
    store_b = create(:store)
    create_social_integration(store: store_a, client_id: 'appid-a')
    create_social_integration(store: store_b, client_id: 'appid-b')

    Spree::Current.store = store_a
    expect(provider.authorization_url(state: 's')).to include('appid=appid-a')

    Spree::Current.store = store_b
    Spree::Current.integrations = nil
    expect(provider.authorization_url(state: 's')).to include('appid=appid-b')
  end
end
