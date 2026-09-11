require 'spec_helper'

RSpec.describe SpreeSocialAuth::Integrations::WeChat do
  it 'groups its card with the other social providers' do
    expect(described_class.integration_group).to eq('authentication')
  end

  describe '#can_connect?' do
    it 'accepts a complete set of credentials' do
      expect(create_social_integration.can_connect?).to be true
    end

    # WeChat publishes no cheap unauthenticated endpoint, so presence is all
    # that can be checked before the first shopper signs in.
    it 'refuses to activate without a secret' do
      integration = described_class.new(store: @default_store)
      integration.preferred_client_id = 'wx_appid'
      integration.preferred_redirect_uri = 'https://shop.example.com/account/callback/wechat'

      expect(integration.can_connect?).to be false
      expect(integration.connection_error_message).to eq(
        Spree.t('spree_social_auth.errors.credentials_missing')
      )
    end

    it 'refuses to activate without a callback URL' do
      integration = described_class.new(store: @default_store)
      integration.preferred_client_id = 'wx_appid'
      integration.preferred_client_secret = 'wx_secret'

      expect(integration.can_connect?).to be false
    end
  end

  it 'does not trust an unverified address by default' do
    expect(create_social_integration.preferred_trust_unverified_email).to be false
  end
end
