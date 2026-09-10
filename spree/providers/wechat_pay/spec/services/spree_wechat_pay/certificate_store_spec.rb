require 'spec_helper'

RSpec.describe SpreeWechatPay::CertificateStore do
  # Platform certificate mode throughout: public key mode resolves to the one
  # configured key and never touches the cache, so it has nothing to say about
  # merging.
  let(:context) do
    merchant_context(verification_mode: 'platform_certificate', public_key_pem: nil, public_key_id: nil)
  end
  let(:client) { instance_double(SpreeWechatPay::Client) }
  # Injected rather than taking the app's store: the test environment runs a
  # null store, and a spec that silently cached nothing would pass while
  # verifying none of this.
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:store) { described_class.new(context: context, client: client, cache: cache) }

  def certificate_entry(serial, pem)
    {
      'serial_no' => serial,
      'encrypt_certificate' => encrypt_like_wechat(pem, associated_data: 'certificate')
    }
  end

  describe '#refresh!' do
    # WeChat serves the old and the new certificate together for 24 hours
    # before a rotation. A refresh that swapped in only what it downloaded would
    # drop the certificate still signing in-flight notifications, and
    # verification would fail for hours.
    it 'merges what it downloaded with what it already held' do
      cache.write(described_class::CACHE_KEY, { 'OLD_SERIAL' => platform_key_pair.to_pem })
      allow(client).to receive(:get).with('/v3/certificates').and_return(
        'data' => [certificate_entry('NEW_SERIAL', platform_key_pair.to_pem)]
      )

      store.refresh!

      expect(store.verification_keys.keys).to contain_exactly('OLD_SERIAL', 'NEW_SERIAL')
    end

    it 'decrypts the downloaded certificates with the APIv3 key' do
      allow(client).to receive(:get).with('/v3/certificates').and_return(
        'data' => [certificate_entry('NEW_SERIAL', platform_key_pair.to_pem)]
      )

      store.refresh!

      expect(store.verification_keys['NEW_SERIAL']).to be_a(OpenSSL::PKey::RSA)
    end

    it 'reports how many certificates it now holds' do
      allow(client).to receive(:get).with('/v3/certificates').and_return(
        'data' => [
          certificate_entry('A_SERIAL', platform_key_pair.to_pem),
          certificate_entry('B_SERIAL', platform_key_pair.to_pem)
        ]
      )

      expect(store.refresh!).to eq(2)
    end

    it 'leaves the cache untouched when the download fails' do
      cache.write(described_class::CACHE_KEY, { 'OLD_SERIAL' => platform_key_pair.to_pem })
      allow(client).to receive(:get).and_raise(
        SpreeWechatPay::ConnectionError.new('WeChat Pay answered 500')
      )

      expect { store.refresh! }.to raise_error(SpreeWechatPay::ConnectionError)
      expect(store.verification_keys.keys).to eq(['OLD_SERIAL'])
    end

    # The most common cause is a wrong APIv3 key, so the message names the
    # operation rather than passing a bare 4xx through.
    it 'names what failed when WeChat rejects the download' do
      allow(client).to receive(:get).and_raise(
        SpreeWechatPay::ApiError.new('签名错误', code: 'SIGN_ERROR')
      )

      expect { store.refresh! }.to raise_error(
        SpreeWechatPay::ApiError, /Could not download WeChat Pay platform certificates/
      )
    end
  end

  describe '#verification_keys' do
    it 'returns the configured public key in public key mode' do
      store = described_class.new(context: merchant_context, client: client, cache: cache)

      expect(store.verification_keys.keys).to eq([WechatPaySpecHelpers::PUBLIC_KEY_ID])
    end

    it 'returns the cached certificates in platform certificate mode' do
      cache.write(described_class::CACHE_KEY, { 'A_SERIAL' => platform_key_pair.to_pem })

      expect(store.verification_keys.keys).to eq(['A_SERIAL'])
    end

    it 'reads the cache rather than WeChat when it is warm' do
      cache.write(described_class::CACHE_KEY, { 'A_SERIAL' => platform_key_pair.to_pem })
      expect(client).not_to receive(:get)

      store.verification_keys
    end

    # The alternative is not a slower verification but no verification at all:
    # WeChat would see every notification rejected and retry it fifteen times.
    it 'fetches once when the cache is cold' do
      expect(client).to receive(:get).with('/v3/certificates').once.and_return(
        'data' => [certificate_entry('A_SERIAL', platform_key_pair.to_pem)]
      )

      expect(store.verification_keys.keys).to eq(['A_SERIAL'])
    end
  end
end
