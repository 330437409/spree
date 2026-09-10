require 'spec_helper'

RSpec.describe SpreeWechatPay::Client do
  let(:context) { merchant_context }
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:connection) do
    Faraday.new(url: SpreeWechatPay::API_HOST) do |faraday|
      faraday.adapter :test, stubs
    end
  end
  let(:client) { described_class.new(context: context, connection: connection) }

  describe 'signing' do
    it 'signs every request over its own path and body' do
      seen = nil
      stubs.post('/v3/pay/transactions/native') do |env|
        seen = env
        [200, { 'Content-Type' => 'application/json' }, '{"code_url":"weixin://wxpay/abc"}']
      end

      client.post('/v3/pay/transactions/native', { appid: 'wx' })

      expect(seen.request_headers['Authorization']).to start_with('WECHATPAY2-SHA256-RSA2048 ')
      expect(seen.request_headers['Authorization']).to include(%(mchid="#{WechatPaySpecHelpers::MERCHANT_ID}"))
    end
  end

  describe 'a successful call' do
    before do
      stubs.get('/v3/certificates') do
        [200, { 'Content-Type' => 'application/json' }, '{"data":[]}']
      end
    end

    it 'returns the parsed body' do
      expect(client.get('/v3/certificates')).to eq('data' => [])
    end
  end

  describe 'a rejection WeChat named' do
    before do
      # The field is nested under `detail`, as WeChat documents it. A flat
      # `field` was what this spec used to stub, which is why the bug survived.
      stubs.post('/v3/pay/transactions/native') do
        [403, { 'Content-Type' => 'application/json' },
         '{"code":"OUT_TRADE_NO_USED","message":"商户订单号重复",' \
         '"detail":{"field":"/out_trade_no","issue":"duplicate out_trade_no","location":"body"}}']
      end
    end

    it 'carries the code, the message and the offending field' do
      expect { client.post('/v3/pay/transactions/native', {}) }.to raise_error(SpreeWechatPay::ApiError) do |error|
        expect(error.code).to eq('OUT_TRADE_NO_USED')
        expect(error.field).to eq('/out_trade_no')
        expect(error.status).to eq(403)
        expect(error.issue).to eq('duplicate out_trade_no')
        expect(error.message).to include('商户订单号重复', 'OUT_TRADE_NO_USED', '/out_trade_no')
      end
    end
  end

  # A 5xx answers nothing about whether the request took effect, so it is
  # reported as an unknown outcome rather than as a failure the caller may act
  # on. Whether to retry is the caller's decision, because only the caller knows
  # how to look up what happened.
  describe 'an answer that says nothing' do
    it 'reports a 5xx as a connection error' do
      stubs.post('/v3/pay/transactions/native') { [500, {}, ''] }

      expect { client.post('/v3/pay/transactions/native', {}) }.to raise_error(SpreeWechatPay::ConnectionError)
    end

    it 'does not retry a create, because a second attempt could take payment twice' do
      attempts = 0
      stubs.post('/v3/pay/transactions/native') do
        attempts += 1
        [500, {}, '']
      end

      expect { client.post('/v3/pay/transactions/native', {}) }.to raise_error(SpreeWechatPay::ConnectionError)
      expect(attempts).to eq(1)
    end

    it 'reports a timeout as a connection error' do
      stubs.post('/v3/pay/transactions/native') { raise Faraday::TimeoutError }

      expect { client.post('/v3/pay/transactions/native', {}) }.to raise_error(SpreeWechatPay::ConnectionError)
    end

    it 'reports a body that is not JSON rather than pretending it parsed' do
      stubs.get('/v3/certificates') { [200, {}, '<html>gateway</html>'] }

      expect { client.get('/v3/certificates') }.to raise_error(SpreeWechatPay::ConnectionError, /not JSON/)
    end
  end

  # WeChat signs every answer it sends. That signature is the whole of what
  # makes an answer WeChat's rather than something the request happened to
  # reach, so a client that is given a verifier believes nothing without one.
  describe 'verifying an answer' do
    let(:verifying_client) do
      described_class.new(context: context, connection: connection, verifier: verifier)
    end
    let(:verifier) do
      SpreeWechatPay::Verifier.new(
        { WechatPaySpecHelpers::PUBLIC_KEY_ID => platform_key_pair.public_key }
      )
    end
    let(:path) { '/v3/pay/transactions/native' }
    let(:payload) { '{"code_url":"weixin://wxpay/abc"}' }

    def wechat_headers_for(payload, key: platform_key_pair)
      timestamp = Time.current.to_i.to_s

      {
        'Content-Type' => 'application/json',
        'Wechatpay-Timestamp' => timestamp,
        'Wechatpay-Nonce' => 'NONCE',
        'Wechatpay-Serial' => WechatPaySpecHelpers::PUBLIC_KEY_ID,
        'Wechatpay-Signature' => sign_like_wechat("#{timestamp}\nNONCE\n#{payload}\n", key: key)
      }
    end

    it 'accepts an answer WeChat signed' do
      stubs.post(path) { [200, wechat_headers_for(payload), payload] }

      expect(verifying_client.post(path, {})).to eq('code_url' => 'weixin://wxpay/abc')
    end

    it 'refuses an answer signed with a key that is not WeChat’s' do
      other_key = OpenSSL::PKey::RSA.new(2048)
      stubs.post(path) { [200, wechat_headers_for(payload, key: other_key), payload] }

      expect { verifying_client.post(path, {}) }.
        to raise_error(SpreeWechatPay::VerificationError, /does not verify/)
    end

    it 'refuses an answer whose body changed after it was signed' do
      stubs.post(path) { [200, wechat_headers_for(payload), '{"code_url":"weixin://wxpay/other"}'] }

      expect { verifying_client.post(path, {}) }.
        to raise_error(SpreeWechatPay::VerificationError, /does not verify/)
    end

    it 'refuses an answer carrying no signature at all' do
      stubs.post(path) { [200, { 'Content-Type' => 'application/json' }, payload] }

      expect { verifying_client.post(path, {}) }.
        to raise_error(SpreeWechatPay::VerificationError, /Missing verification headers/)
    end

    it 'refuses an answer signed outside the replay window' do
      stale = wechat_headers_for(payload)
      stale['Wechatpay-Timestamp'] = (Time.current.to_i - 10.minutes.to_i).to_s
      stubs.post(path) { [200, stale, payload] }

      expect { verifying_client.post(path, {}) }.
        to raise_error(SpreeWechatPay::VerificationError, /replay window/)
    end

    # An answer that cannot be attributed says nothing about whether the request
    # took effect, so it is reported the way a dropped connection is — and a
    # create is never repeated on the strength of it.
    it 'reports it as an unknown outcome rather than as a refusal' do
      attempts = 0
      stubs.post(path) do
        attempts += 1
        [200, { 'Content-Type' => 'application/json' }, payload]
      end

      expect { verifying_client.post(path, {}) }.to raise_error(SpreeWechatPay::ConnectionError)
      expect(attempts).to eq(1)
    end

    # The download that supplies the verification keys cannot be verified
    # against the keys it is fetching, so a client without a verifier is what
    # the certificate store is given.
    it 'believes a client that was given no verifier' do
      stubs.get('/v3/certificates') { [200, { 'Content-Type' => 'application/json' }, '{"data":[]}'] }

      expect(client.get('/v3/certificates')).to eq('data' => [])
    end
  end

  # Queries are reads: retrying one cannot move money or create a second
  # transaction.
  describe 'retrying a query' do
    it 'retries a read that failed, then returns the answer' do
      attempts = 0
      stubs.get('/v3/certificates') do
        attempts += 1
        attempts == 1 ? [500, {}, ''] : [200, {}, '{"data":[]}']
      end

      expect(client.get('/v3/certificates')).to eq('data' => [])
      expect(attempts).to eq(2)
    end

    it 'gives up and reports the failure' do
      attempts = 0
      stubs.get('/v3/certificates') do
        attempts += 1
        [500, {}, '']
      end

      expect { client.get('/v3/certificates') }.to raise_error(SpreeWechatPay::ConnectionError)
      expect(attempts).to eq(described_class::QUERY_RETRIES + 1)
    end
  end
end
