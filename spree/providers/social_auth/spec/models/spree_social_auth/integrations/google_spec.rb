require 'spec_helper'

RSpec.describe SpreeSocialAuth::Integrations::Google do
  it 'groups its card with the other social providers' do
    expect(described_class.integration_group).to eq('authentication')
  end

  describe '#can_connect?' do
    it 'accepts a complete set of credentials' do
      integration = create_social_integration(
        integration_class: described_class,
        redirect_uri: 'https://shop.example.com/account/callback/google'
      )

      expect(integration.can_connect?).to be true
    end

    it 'refuses to activate without a secret' do
      integration = described_class.new(store: @default_store)
      integration.preferred_client_id = 'google-client-id'
      integration.preferred_redirect_uri = 'https://shop.example.com/account/callback/google'

      expect(integration.can_connect?).to be false
    end
  end
end
