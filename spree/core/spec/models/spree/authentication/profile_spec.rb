require 'spec_helper'

describe Spree::Authentication::Profile do
  subject(:profile) do
    described_class.new(provider: 'wechat', uid: 'openid-1', email: email, email_verified: email_verified,
                        info: { nickname: 'Ada' }, tokens: { 'access_token' => 'token-1' })
  end

  let(:email) { 'ada@example.com' }
  let(:email_verified) { nil }

  describe 'validations' do
    it 'requires a provider and a uid' do
      expect(described_class.new).not_to be_valid
      expect(described_class.new(provider: 'wechat', uid: 'openid-1')).to be_valid
    end
  end

  describe '#verified_email' do
    context 'when the provider asserts the address is verified' do
      let(:email_verified) { true }

      it 'returns the address' do
        expect(profile.verified_email).to eq('ada@example.com')
      end
    end

    context 'when the provider says nothing about the address' do
      it 'returns nil by default' do
        expect(profile.verified_email).to be_nil
      end

      it 'returns the address only for an integration that trusts its directory' do
        expect(profile.verified_email(trust_unverified: true)).to eq('ada@example.com')
      end
    end

    # An explicit false is always obeyed, however the integration is configured.
    context 'when the provider says the address is not verified' do
      let(:email_verified) { false }

      it 'returns nil even when the integration trusts unverified addresses' do
        expect(profile.verified_email(trust_unverified: true)).to be_nil
      end
    end

    context 'when the provider returned no address' do
      let(:email) { nil }
      let(:email_verified) { true }

      it 'returns nil' do
        expect(profile.verified_email).to be_nil
      end
    end
  end

  describe '#token' do
    it 'reads a token whatever the key type' do
      expect(profile.token(:access_token)).to eq('token-1')
      expect(profile.token?(:access_token)).to be true
      expect(profile.token?(:refresh_token)).to be false
    end
  end

  describe '.from_h' do
    it 'round-trips through the signed registration token payload' do
      restored = described_class.from_h(JSON.parse(profile.to_h.to_json))

      expect(restored.provider).to eq('wechat')
      expect(restored.uid).to eq('openid-1')
      expect(restored.info).to include('nickname' => 'Ada')
      expect(restored.verified_email(trust_unverified: true)).to eq('ada@example.com')
    end

    it 'round-trips string keys as they come back from JSON' do
      payload = { 'provider' => 'douyin', 'uid' => 'open-1', 'info' => { 'nickname' => 'Bo' }, 'tokens' => {} }

      expect(described_class.from_h(payload).uid).to eq('open-1')
    end
  end
end
