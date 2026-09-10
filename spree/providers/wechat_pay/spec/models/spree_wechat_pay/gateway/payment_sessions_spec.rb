require 'spec_helper'

RSpec.describe SpreeWechatPay::Gateway::PaymentSessions do
  let(:gateway) { wechat_gateway }
  let(:cart) { wechat_cart }

  def stub_client(path, response)
    client = instance_double(SpreeWechatPay::Client)
    if response.is_a?(StandardError)
      allow(client).to receive(:post).with(path, anything).and_raise(response)
      allow(client).to receive(:get).with(path, any_args).and_raise(response)
    else
      allow(client).to receive(:post).with(path, anything).and_return(response)
      allow(client).to receive(:get).with(path, any_args).and_return(response)
    end
    allow(gateway).to receive(:client).and_return(client)
    client
  end

  describe '#create_payment_session' do
    let(:code_url) { 'weixin://wxpay/bizpayurl/up?pr=NwY5Mz9&groupid=00' }

    before { stub_client('/v3/pay/transactions/native', { 'code_url' => code_url }) }

    it 'creates a session addressed by our merchant order number' do
      session = gateway.create_payment_session(order: cart)

      expect(session).to be_persisted
      expect(session.external_id).to eq(session.merchant_order_number)
      expect(SpreeWechatPay::MerchantOrderNumber.valid?(session.external_id)).to be true
    end

    it 'hands the storefront the QR link to render' do
      session = gateway.create_payment_session(order: cart, external_data: { scene: 'native' })

      expect(session.code_url).to eq(code_url)
      expect(session.scene).to eq('native')
    end

    # Two clocks, and they are not the same: the transaction stays payable for
    # days while the QR link it came with is good for two hours.
    it 'separates the token lifetime from the transaction lifetime' do
      session = gateway.create_payment_session(order: cart)

      expect(session.payload_expires_at).to be_within(1.minute).of(2.hours.from_now)
      expect(session.expires_at).to be_within(1.minute).of(7.days.from_now)
      expect(session.payload_expired?).to be false
    end

    it 'sends the amount in fen, which is what WeChat counts in' do
      expect(gateway.client).to receive(:post).with(
        '/v3/pay/transactions/native',
        hash_including('amount' => { 'total' => Spree::Money.new(cart.total, currency: 'CNY').cents,
                                     'currency' => 'CNY' })
      ).and_return('code_url' => code_url)

      gateway.create_payment_session(order: cart)
    end

    it 'sends a description, which WeChat requires and shows the customer' do
      expect(gateway.client).to receive(:post).with(
        '/v3/pay/transactions/native', hash_including('description' => satisfy(&:present?))
      ).and_return('code_url' => code_url)

      gateway.create_payment_session(order: cart)
    end

    # Native carries no payer identity, but WeChat still wants an identifier
    # bound to the merchant number.
    it 'sends the bound application identifier' do
      expect(gateway.client).to receive(:post).with(
        '/v3/pay/transactions/native',
        hash_including('appid' => WechatPaySpecHelpers::BOUND_APP_ID)
      ).and_return('code_url' => code_url)

      gateway.create_payment_session(order: cart)
    end

    it 'omits the scene object rather than sending an incomplete one' do
      expect(gateway.client).to receive(:post).with(
        '/v3/pay/transactions/native', hash_excluding('scene_info')
      ).and_return('code_url' => code_url)

      gateway.create_payment_session(order: cart)
    end

    it 'sends the customer IP when the storefront forwards it' do
      expect(gateway.client).to receive(:post).with(
        '/v3/pay/transactions/native',
        hash_including('scene_info' => { 'payer_client_ip' => '203.0.113.7' })
      ).and_return('code_url' => code_url)

      gateway.create_payment_session(order: cart, external_data: { payer_client_ip: '203.0.113.7' })
    end

    it 'points WeChat at this store\'s own callback URL' do
      expect(gateway.client).to receive(:post).with(
        '/v3/pay/transactions/native', hash_including('notify_url' => gateway.webhook_url)
      ).and_return('code_url' => code_url)

      gateway.create_payment_session(order: cart)
    end

    it 'refuses a zero amount rather than asking WeChat to reject it' do
      expect { gateway.create_payment_session(order: cart, amount: 0) }.to raise_error(
        Spree::Core::GatewayError
      )
    end

    # A scene the merchant never switched on is refused, not substituted: the
    # storefront asked for it because it can drive that one.
    it 'refuses a scene that is not enabled' do
      expect { gateway.create_payment_session(order: cart, external_data: { scene: 'jsapi' }) }.to raise_error(
        Spree::Core::GatewayError, /jsapi/
      )
    end

    it 'needs to be told which scene when more than one is enabled' do
      gateway.preferred_enabled_scenes = %w[native jsapi]
      gateway.save!

      expect { gateway.create_payment_session(order: cart) }.to raise_error(
        Spree::Core::GatewayError, /scene/
      )
    end

    it 'refuses to work at all with no scene enabled' do
      gateway.preferred_enabled_scenes = []
      gateway.save!

      expect { gateway.create_payment_session(order: cart) }.to raise_error(Spree::Core::GatewayError)
    end
  end

  # JSAPI is the same transaction as Native with a payer added: the appid is the
  # official account's, and WeChat will not accept the order without the payer's
  # openid.
  describe 'the JSAPI scene' do
    let(:gateway) { wechat_gateway(enabled_scenes: %w[jsapi]) }
    let(:oauth) { instance_double(SpreeWechatPay::Oauth) }
    let(:prepay_id) { 'wx281410272009395522657a690389285100' }

    before do
      allow(gateway).to receive(:oauth).and_return(oauth)
      allow(oauth).to receive(:openid_for).and_return('oUpF8uMuAJO_M2pxb1Q9zNjWeS6o')
      stub_client('/v3/pay/transactions/jsapi', { 'prepay_id' => prepay_id })
    end

    it 'exchanges the authorization code rather than trusting a supplied openid' do
      expect(oauth).to receive(:openid_for).with(scene: 'jsapi', code: 'CODE123')

      gateway.create_payment_session(order: cart, external_data: { scene: 'jsapi', code: 'CODE123' })
    end

    it 'names the payer on the order' do
      expect(gateway.client).to receive(:post).with(
        '/v3/pay/transactions/jsapi',
        hash_including('payer' => { 'openid' => 'oUpF8uMuAJO_M2pxb1Q9zNjWeS6o' })
      ).and_return('prepay_id' => prepay_id)

      gateway.create_payment_session(order: cart, external_data: { scene: 'jsapi', code: 'CODE123' })
    end

    it 'uses the official account identifier, not the bound one' do
      expect(gateway.client).to receive(:post).with(
        '/v3/pay/transactions/jsapi', hash_including('appid' => 'wx_jsapi_appid')
      ).and_return('prepay_id' => prepay_id)

      gateway.create_payment_session(order: cart, external_data: { scene: 'jsapi', code: 'CODE123' })
    end

    # The storefront receives a finished parameter set: it never signs, and it
    # never holds the merchant private key.
    it 'hands the storefront signed launch parameters' do
      session = gateway.create_payment_session(
        order: cart, external_data: { scene: 'jsapi', code: 'CODE123' }
      )

      expect(session.external_data['launch_params']).to include(
        'appId' => 'wx_jsapi_appid',
        'package' => "prepay_id=#{prepay_id}",
        'signType' => 'RSA'
      )
      expect(session.external_data['launch_params']['paySign']).to be_present
    end

    # Without a code there is no identity, and WeChat's own complaint about a
    # missing payer is a bare parameter error.
    it 'refuses a session with no authorization code' do
      expect { gateway.create_payment_session(order: cart, external_data: { scene: 'jsapi' }) }
        .to raise_error(Spree::Core::GatewayError, /authorization code/)
    end
  end

  # A scene that is configured but not built must say so, rather than failing
  # somewhere further in where the cause is unrecognisable.
  # The mini program is the same pipeline as JSAPI against the same endpoint;
  # only the identifier and the launch contract differ.
  describe 'the mini program scene' do
    let(:gateway) { wechat_gateway(enabled_scenes: %w[mini_program]) }
    let(:oauth) { instance_double(SpreeWechatPay::Oauth) }
    let(:prepay_id) { 'wx281410272009395522657a690389285100' }

    before do
      allow(gateway).to receive(:oauth).and_return(oauth)
      allow(oauth).to receive(:openid_for).and_return('oUpF8uMuAJO_M2pxb1Q9zNjWeS6o')
      stub_client('/v3/pay/transactions/jsapi', { 'prepay_id' => prepay_id })
    end

    it 'places the order on the shared JSAPI endpoint' do
      expect(gateway.client).to receive(:post).with(
        '/v3/pay/transactions/jsapi', hash_including('appid' => 'wx_mini_appid')
      ).and_return('prepay_id' => prepay_id)

      gateway.create_payment_session(
        order: cart, external_data: { scene: 'mini_program', code: 'JSCODE123' }
      )
    end

    it 'names the payer, as the other identity scene does' do
      expect(gateway.client).to receive(:post).with(
        '/v3/pay/transactions/jsapi',
        hash_including('payer' => { 'openid' => 'oUpF8uMuAJO_M2pxb1Q9zNjWeS6o' })
      ).and_return('prepay_id' => prepay_id)

      gateway.create_payment_session(
        order: cart, external_data: { scene: 'mini_program', code: 'JSCODE123' }
      )
    end

    # Where the two part company: the launch call carries no application
    # identifier, and repeating it does not produce an error — the payment just
    # never starts.
    it 'hands back launch parameters with no application identifier' do
      session = gateway.create_payment_session(
        order: cart, external_data: { scene: 'mini_program', code: 'JSCODE123' }
      )

      expect(session.external_data['launch_params']).not_to have_key('appId')
      expect(session.external_data['launch_params']['package']).to eq("prepay_id=#{prepay_id}")
    end
  end

  describe 'a scene that is not implemented yet' do
    let(:gateway) { wechat_gateway(enabled_scenes: %w[h5]) }

    it 'refuses plainly' do
      expect { gateway.create_payment_session(order: cart) }.to raise_error(
        Spree::Core::GatewayError, /not available in this version/
      )
    end
  end

  describe '#update_payment_session' do
    let(:code_url) { 'weixin://wxpay/bizpayurl/up?pr=old&groupid=00' }
    let(:new_code_url) { 'weixin://wxpay/bizpayurl/up?pr=new&groupid=00' }
    let(:session) { gateway.create_payment_session(order: cart) }

    before { stub_client('/v3/pay/transactions/native', { 'code_url' => code_url }) }

    # Asking twice must not open a second transaction.
    it 'does nothing when the amount is unchanged and the token is still live' do
      session = gateway.create_payment_session(order: cart)
      expect(gateway.client).not_to receive(:post)

      gateway.update_payment_session(payment_session: session)
    end

    it 're-issues under the same number when only the token has lapsed' do
      session = gateway.create_payment_session(order: cart)
      session.update!(external_data: session.external_data.merge(
        'payload_expires_at' => 1.minute.ago.iso8601
      ))
      expect(gateway.client).to receive(:post).with(
        '/v3/pay/transactions/native', hash_including('out_trade_no' => session.merchant_order_number)
      ).and_return('code_url' => new_code_url)

      gateway.update_payment_session(payment_session: session.reload)

      expect(session.reload.code_url).to eq(new_code_url)
      expect(session.payload_expired?).to be false
    end

    # WeChat cannot change the amount of an open transaction, so the old one is
    # closed and a new one takes its place under a fresh number.
    it 'replaces the transaction when the amount moves' do
      session = gateway.create_payment_session(order: cart)
      old_number = session.merchant_order_number
      allow(gateway.client).to receive(:post).with(
        "/v3/pay/transactions/out-trade-no/#{old_number}/close", anything
      ).and_return({})
      allow(gateway.client).to receive(:post).with(
        '/v3/pay/transactions/native', anything
      ).and_return('code_url' => new_code_url)

      gateway.update_payment_session(payment_session: session, amount: cart.total + 5)

      expect(session.reload.merchant_order_number).not_to eq(old_number)
      expect(SpreeWechatPay::MerchantOrderNumber.valid?(session.merchant_order_number)).to be true
      expect(session.amount).to eq(cart.total + 5)
    end

    # A replacement still happens if the old transaction cannot be closed — a
    # number that was never created has nothing to close.
    it 'carries on when the old transaction cannot be closed' do
      session = gateway.create_payment_session(order: cart)
      allow(gateway.client).to receive(:post).with(
        %r{/close$}, anything
      ).and_raise(SpreeWechatPay::ApiError.new('订单不存在', code: 'ORDER_NOT_EXIST', status: 404))
      allow(gateway.client).to receive(:post).with(
        '/v3/pay/transactions/native', anything
      ).and_return('code_url' => new_code_url)

      gateway.update_payment_session(payment_session: session, amount: cart.total + 5)

      expect(session.reload.code_url).to eq(new_code_url)
    end
  end

  describe '#complete_payment_session' do
    let(:session) { gateway.create_payment_session(order: cart) }

    before { stub_client('/v3/pay/transactions/native', { 'code_url' => 'weixin://a' }) }

    def stub_query(response)
      allow(gateway.client).to receive(:get).with(%r{out-trade-no}, any_args).and_return(response)
    end

    it 'settles on what WeChat reports, not on what the storefront claims' do
      session = gateway.create_payment_session(order: cart)
      stub_query(
        'trade_state' => 'SUCCESS', 'transaction_id' => '4200001234',
        'out_trade_no' => session.merchant_order_number, 'payer' => { 'openid' => 'oUpF8u' }
      )

      gateway.complete_payment_session(payment_session: session)

      expect(session.reload).to be_completed
      expect(session.transaction_id).to eq('4200001234')
    end

    it 'records WeChat own identifiers on the payment' do
      session = gateway.create_payment_session(order: cart)
      stub_query(
        'trade_state' => 'SUCCESS', 'transaction_id' => '4200001234',
        'out_trade_no' => session.merchant_order_number, 'payer' => { 'openid' => 'oUpF8u' }
      )

      gateway.complete_payment_session(payment_session: session)

      payment = session.reload.payment
      expect(payment).to be_present
      expect(payment.metadata['wechat_pay_transaction_id']).to eq('4200001234')
      expect(payment.metadata['wechat_pay_openid']).to eq('oUpF8u')
    end

    # WeChat's own instruction: close before declaring failure, because an
    # unpaid transaction can still be paid.
    it 'closes before failing an unpaid transaction' do
      session = gateway.create_payment_session(order: cart)
      stub_query('trade_state' => 'NOTPAY')
      expect(gateway.client).to receive(:post).with(
        "/v3/pay/transactions/out-trade-no/#{session.merchant_order_number}/close", anything
      ).and_return({})

      gateway.complete_payment_session(payment_session: session)

      expect(session.reload).to be_failed
    end

    # The race resolving in the customer's favour: the close is refused because
    # the money arrived between the query and the close, so we settle instead.
    it 'settles when the close is refused because the customer just paid' do
      session = gateway.create_payment_session(order: cart)
      call = 0
      allow(gateway.client).to receive(:get).with(%r{out-trade-no}, any_args) do
        call += 1
        if call == 1
          { 'trade_state' => 'NOTPAY' }
        else
          { 'trade_state' => 'SUCCESS', 'transaction_id' => '4200001234',
            'out_trade_no' => session.merchant_order_number }
        end
      end
      allow(gateway.client).to receive(:post).with(%r{/close$}, anything).and_raise(
        SpreeWechatPay::ApiError.new('订单已支付', code: 'ORDER_PAID', status: 400)
      )

      gateway.complete_payment_session(payment_session: session)

      expect(session.reload).to be_completed
    end

    it 'cancels a session whose transaction WeChat already closed' do
      session = gateway.create_payment_session(order: cart)
      stub_query('trade_state' => 'CLOSED')

      gateway.complete_payment_session(payment_session: session)

      expect(session.reload).to be_canceled
    end

    it 'leaves the session alone while the customer is still paying' do
      session = gateway.create_payment_session(order: cart)
      stub_query('trade_state' => 'USERPAYING')
      allow(gateway.client).to receive(:post).with(%r{/close$}, anything).and_raise(
        SpreeWechatPay::ApiError.new('用户支付中', code: 'USERPAYING', status: 400)
      )

      expect { gateway.complete_payment_session(payment_session: session) }.to raise_error(
        SpreeWechatPay::ApiError
      )
      expect(session.reload.status).to eq('pending')
    end
  end
end
