require 'spec_helper'

RSpec.describe SpreeWechatPay::Verifier do
  let(:body) { '{"id":"EV-2018022511223320873","event_type":"TRANSACTION.SUCCESS"}' }
  let(:timestamp) { '1554208460' }
  let(:nonce) { 'NONCE_STRING' }
  let(:keys) { { WechatPaySpecHelpers::PUBLIC_KEY_ID => platform_key_pair.public_key } }
  let(:verifier) { described_class.new(keys) }

  def signature_for(body, timestamp, nonce, key: platform_key_pair)
    sign_like_wechat("#{timestamp}\n#{nonce}\n#{body}\n", key: key)
  end

  describe '#verify!' do
    it 'accepts a signature over the three-line string the specification defines' do
      expect(
        verifier.verify!(
          body: body, timestamp: timestamp, nonce: nonce,
          signature: signature_for(body, timestamp, nonce),
          serial: WechatPaySpecHelpers::PUBLIC_KEY_ID
        )
      ).to be true
    end

    it 'rejects a signature when the body was changed after signing' do
      signature = signature_for(body, timestamp, nonce)

      expect do
        verifier.verify!(
          body: '{"event_type":"TRANSACTION.SUCCESS"}', timestamp: timestamp, nonce: nonce,
          signature: signature, serial: WechatPaySpecHelpers::PUBLIC_KEY_ID
        )
      end.to raise_error(described_class::InvalidSignature, /does not match/)
    end

    it 'rejects a signature made with a different key' do
      other_key = OpenSSL::PKey::RSA.new(2048)

      expect do
        verifier.verify!(
          body: body, timestamp: timestamp, nonce: nonce,
          signature: signature_for(body, timestamp, nonce, key: other_key),
          serial: WechatPaySpecHelpers::PUBLIC_KEY_ID
        )
      end.to raise_error(described_class::InvalidSignature, /does not match/)
    end

    # During a certificate rotation WeChat signs with a certificate this
    # installation has not downloaded yet. Saying so is the difference between
    # an operator checking the refresh job and one staring at "invalid
    # signature".
    it 'names the missing serial rather than reporting a bad signature' do
      expect do
        verifier.verify!(
          body: body, timestamp: timestamp, nonce: nonce,
          signature: signature_for(body, timestamp, nonce),
          serial: WechatPaySpecHelpers::PLATFORM_SERIAL
        )
      end.to raise_error(described_class::InvalidSignature, /No verification key for serial #{WechatPaySpecHelpers::PLATFORM_SERIAL}/)
    end

    it 'rejects a request missing the verification headers' do
      expect do
        verifier.verify!(body: body, timestamp: nil, nonce: nonce, signature: 'x', serial: 'x')
      end.to raise_error(described_class::InvalidSignature, /Missing verification headers/)
    end

    it 'rejects a signature that is not Base64' do
      expect do
        verifier.verify!(
          body: body, timestamp: timestamp, nonce: nonce,
          signature: 'not base64!!', serial: WechatPaySpecHelpers::PUBLIC_KEY_ID
        )
      end.to raise_error(described_class::InvalidSignature, /Malformed signature encoding/)
    end
  end
end
