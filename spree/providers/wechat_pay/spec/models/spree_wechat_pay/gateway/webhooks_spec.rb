require 'spec_helper'

RSpec.describe SpreeWechatPay::Gateway::Webhooks do
  let(:gateway) { wechat_gateway }
  let(:cart) { wechat_cart }
  let(:number) { 'R1001-abcd1234' }

  let!(:session) do
    Spree::PaymentSessions::WechatPay.create!(
      owner: cart,
      payment_method: gateway,
      amount: cart.total,
      currency: 'CNY',
      status: 'pending',
      external_id: number,
      external_data: { 'scene' => 'native' }
    )
  end

  let(:transaction) do
    {
      'appid' => WechatPaySpecHelpers::BOUND_APP_ID,
      'mchid' => WechatPaySpecHelpers::MERCHANT_ID,
      'out_trade_no' => number,
      'transaction_id' => '4200001234202601011234567890',
      'trade_type' => 'NATIVE',
      'trade_state' => 'SUCCESS',
      'trade_state_desc' => '支付成功',
      'payer' => { 'openid' => 'oUpF8uMuAJO_M2pxb1Q9zNjWeS6o' },
      'amount' => { 'total' => 1234, 'payer_total' => 1234, 'currency' => 'CNY' }
    }
  end

  def envelope(event_type: 'TRANSACTION.SUCCESS', resource: transaction, original_type: 'transaction')
    {
      'id' => 'EV-2018022511223320873',
      'create_time' => '2026-09-10T13:29:35+08:00',
      'resource_type' => 'encrypt-resource',
      'event_type' => event_type,
      'summary' => '支付成功',
      'resource' => encrypt_like_wechat(
        JSON.generate(resource), associated_data: original_type
      ).merge('original_type' => original_type)
    }
  end

  # Signs the body the way WeChat does, over timestamp, nonce and the raw bytes.
  def signed_request(body, timestamp: '1554208460', nonce: 'NONCE', key: platform_key_pair)
    headers = {
      'Wechatpay-Timestamp' => timestamp,
      'Wechatpay-Nonce' => nonce,
      'Wechatpay-Serial' => WechatPaySpecHelpers::PUBLIC_KEY_ID,
      'Wechatpay-Signature' => sign_like_wechat("#{timestamp}\n#{nonce}\n#{body}\n", key: key)
    }
    [body, headers]
  end

  describe '#parse_webhook_event' do
    it 'recognises a successful payment' do
      body, headers = signed_request(JSON.generate(envelope))

      result = gateway.parse_webhook_event(body, headers)

      expect(result[:action]).to eq(:captured)
      expect(result[:payment_session]).to eq(session)
    end

    # WeChat knows the transaction by its own identifiers, and the payment is
    # what an operator looks at when reconciling.
    it 'carries WeChat own identifiers for the payment' do
      body, headers = signed_request(JSON.generate(envelope))

      metadata = gateway.parse_webhook_event(body, headers)[:metadata]

      expect(metadata['wechat_pay_transaction_id']).to eq('4200001234202601011234567890')
      expect(metadata['wechat_pay_trade_state']).to eq('SUCCESS')
      expect(metadata['wechat_pay_openid']).to eq('oUpF8uMuAJO_M2pxb1Q9zNjWeS6o')
      expect(metadata['wechat_pay_out_trade_no']).to eq(number)
    end

    it 'accepts the headers in the form a Rack request presents them' do
      body, plain = signed_request(JSON.generate(envelope))
      rack_headers = plain.transform_keys { |name| "HTTP_#{name.upcase.tr('-', '_')}" }

      expect(gateway.parse_webhook_event(body, rack_headers)[:action]).to eq(:captured)
    end

    # Everything below is refused, and a refusal has to be loud: an unverified
    # notification that we acted on would be a payment we invented.
    it 'refuses a signature made with the wrong key' do
      other_key = OpenSSL::PKey::RSA.new(2048)
      body, headers = signed_request(JSON.generate(envelope), key: other_key)

      expect { gateway.parse_webhook_event(body, headers) }.to raise_error(
        Spree::PaymentMethod::WebhookSignatureError
      )
    end

    it 'refuses a body that changed after signing' do
      body, headers = signed_request(JSON.generate(envelope))
      tampered = body.sub('EV-2018022511223320873', 'EV-tampered-by-someone-else')

      expect { gateway.parse_webhook_event(tampered, headers) }.to raise_error(
        Spree::PaymentMethod::WebhookSignatureError
      )
    end

    it 'refuses a callback signed by a key this merchant does not hold' do
      body, headers = signed_request(JSON.generate(envelope))
      headers['Wechatpay-Serial'] = WechatPaySpecHelpers::PLATFORM_SERIAL

      expect { gateway.parse_webhook_event(body, headers) }.to raise_error(
        Spree::PaymentMethod::WebhookSignatureError, /No verification key/
      )
    end

    it 'refuses a body that verifies but is not the JSON it claims to be' do
      body, headers = signed_request('<html>not json</html>')

      expect { gateway.parse_webhook_event(body, headers) }.to raise_error(
        Spree::PaymentMethod::WebhookSignatureError, /Malformed webhook payload/
      )
    end

    # WeChat sends many kinds of notification to one URL, and one store's
    # callback can receive another's traffic.
    it 'ignores an event it does not act on' do
      body, headers = signed_request(JSON.generate(envelope(event_type: 'TRANSACTION.CLOSED')))

      expect(gateway.parse_webhook_event(body, headers)).to be_nil
    end

    it 'ignores a transaction this store does not own' do
      body, headers = signed_request(
        JSON.generate(envelope(resource: transaction.merge('out_trade_no' => 'not-ours')))
      )

      expect(gateway.parse_webhook_event(body, headers)).to be_nil
    end

    it 'ignores an envelope that is not an encrypted resource' do
      body, headers = signed_request(
        JSON.generate(envelope.merge('resource_type' => 'plain'))
      )

      expect(gateway.parse_webhook_event(body, headers)).to be_nil
    end

    # A notification we cannot decrypt is one we must not act on, and WeChat
    # answers that by retrying — which is the correct outcome for a wrong APIv3
    # key, because silence would look like success.
    it 'raises when the payload cannot be decrypted' do
      body, headers = signed_request(JSON.generate(envelope))
      gateway.preferred_api_v3_key = 'b' * 32

      expect { gateway.parse_webhook_event(body, headers) }.to raise_error(SpreeWechatPay::Aead::Error)
    end
  end
end
