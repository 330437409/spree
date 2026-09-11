require 'spec_helper'

RSpec.describe SpreeSocialAuth::Integrations::Douyin do
  it 'groups its card with the other social providers' do
    expect(described_class.integration_group).to eq('authentication')
  end

  describe '#can_connect?' do
    it 'accepts a complete set of credentials' do
      integration = create_social_integration(
        integration_class: described_class,
        redirect_uri: 'https://shop.example.com/account/callback/douyin'
      )

      expect(integration.can_connect?).to be true
    end

    # Douyin refuses a callback URL carrying a query string, and only says so
    # when a shopper tries to sign in — so it is caught at activation.
    it 'refuses a callback URL with a query string' do
      integration = described_class.new(store: @default_store)
      integration.preferred_client_id = 'dy_key'
      integration.preferred_client_secret = 'dy_secret'
      integration.preferred_redirect_uri = 'https://shop.example.com/account/callback/douyin?from=login'

      expect(integration.can_connect?).to be false
      expect(integration.connection_error_message).to eq(
        Spree.t('spree_social_auth.errors.redirect_uri_must_not_have_query')
      )
    end

    it 'refuses to activate without a secret' do
      integration = described_class.new(store: @default_store)
      integration.preferred_client_id = 'dy_key'
      integration.preferred_redirect_uri = 'https://shop.example.com/account/callback/douyin'

      expect(integration.can_connect?).to be false
      expect(integration.connection_error_message).to eq(
        Spree.t('spree_social_auth.errors.credentials_missing')
      )
    end
  end

  it 'does not trust an unverified address by default' do
    integration = create_social_integration(
      integration_class: described_class,
      redirect_uri: 'https://shop.example.com/account/callback/douyin'
    )

    expect(integration.preferred_trust_unverified_email).to be false
  end
end
