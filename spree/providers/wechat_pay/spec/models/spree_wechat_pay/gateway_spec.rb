require 'spec_helper'

RSpec.describe SpreeWechatPay::Gateway do
  let(:store) { create(:store) }
  let(:gateway) { described_class.new(store: store, name: 'WeChat Pay') }

  it 'registers itself as a payment provider' do
    expect(Spree.payment_methods.map(&:to_s)).to include('SpreeWechatPay::Gateway')
  end

  # The wire type the admin and the API use. Derived from the outer module
  # because the demodulized leaf collapses every gateway to `gateway`.
  it 'reports a distinct api_type' do
    expect(described_class.api_type).to eq('wechat_pay')
  end

  it 'names itself' do
    expect(described_class.new.default_name).to eq('WeChat Pay')
  end

  describe 'capabilities' do
    it 'always goes through a payment session' do
      expect(gateway.session_required?).to be true
    end

    # WeChat accepts a refund and settles it later, so a refund starts in
    # `processing` and is resolved by notification or reconciliation.
    it 'claims asynchronous refunds' do
      expect(gateway.async_refunds?).to be true
    end

    # Nothing here sends an amount in a currency WeChat will not settle, so a
    # store in another currency must not be offered the method at all.
    it 'is offered only for orders in yuan' do
      order = build(:order, currency: 'USD')

      expect(gateway.available_for_order?(order)).to be false
    end

    it 'is offered for an order in yuan' do
      order = build(:order, currency: 'CNY')

      expect(gateway.available_for_order?(order)).to be true
    end

    it 'holds no reusable customer instrument' do
      expect(gateway.source_required?).to be false
      expect(gateway.payment_source_class).to be_nil
      expect(gateway.payment_profiles_supported?).to be false
      expect(gateway.setup_session_supported?).to be false
    end
  end

  describe 'capture method' do
    it 'accepts capture at checkout' do
      gateway.capture_method = 'checkout'

      expect(gateway).to be_valid
    end

    # WeChat offers no general authorize-then-capture split, so this is a
    # configuration the gateway cannot keep. Rejecting it when the method is
    # saved is the point: the alternative is discovering it when a dispatch
    # tries to take money that was already taken.
    it 'refuses a capture method it cannot honour' do
      gateway.capture_method = 'on_dispatch'

      expect(gateway).not_to be_valid
      expect(gateway.errors.attribute_names).to include(:capture_method)
    end

    it 'refuses an inherited capture method it cannot honour' do
      allow(gateway).to receive(:resolved_capture_method).and_return('manual')

      expect(gateway).not_to be_valid
      expect(gateway.errors.attribute_names).to include(:capture_method)
    end

    it 'names the problem rather than saying the value is invalid' do
      gateway.capture_method = 'manual'
      gateway.valid?

      expect(gateway.errors[:capture_method].first).to include('capture at checkout')
    end
  end

  describe 'merchant mode' do
    before { gateway.capture_method = 'checkout' }

    it 'accepts direct mode' do
      gateway.preferred_merchant_mode = 'direct'

      expect(gateway).to be_valid
    end

    # `merchant_mode` is a future-compatibility preference, not a capability:
    # only direct is implemented, so anything else is refused plainly rather
    # than branched on later.
    it 'refuses a mode that is not direct' do
      gateway.preferred_merchant_mode = 'partner'

      expect(gateway).not_to be_valid
      expect(gateway.errors[:base].join).to include('direct')
    end
  end

  describe 'scene identifiers' do
    before { gateway.capture_method = 'checkout' }

    it 'accepts a scene that carries its identifier' do
      gateway.preferred_enabled_scenes = ['native']
      gateway.preferred_bound_app_id = 'wx_bound_appid'

      expect(gateway).to be_valid
    end

    # A scene ticked without its identifier would otherwise fail only when the
    # first payment is placed and WeChat rejects the missing appid.
    it 'refuses Native without a bound application identifier' do
      gateway.preferred_enabled_scenes = ['native']

      expect(gateway).not_to be_valid
      expect(gateway.errors.attribute_names).to include(:bound_app_id)
    end

    it 'refuses H5 without a bound application identifier' do
      gateway.preferred_enabled_scenes = ['h5']

      expect(gateway).not_to be_valid
      expect(gateway.errors.attribute_names).to include(:bound_app_id)
    end

    it 'refuses APP without its application identifier' do
      gateway.preferred_enabled_scenes = ['app']

      expect(gateway).not_to be_valid
      expect(gateway.errors.attribute_names).to include(:app_app_id)
    end

    it 'refuses JSAPI without its application identifier' do
      gateway.preferred_enabled_scenes = ['jsapi']

      expect(gateway).not_to be_valid
      expect(gateway.errors.attribute_names).to include(:jsapi_app_id)
    end

    it 'names the scene that is missing its identifier' do
      gateway.preferred_enabled_scenes = ['native']
      gateway.valid?

      expect(gateway.errors[:bound_app_id].first).to include('native')
    end

    it 'ignores a scene outside the known vocabulary' do
      gateway.preferred_enabled_scenes = ['micropay']

      expect(gateway).to be_valid
    end
  end

  describe 'credentials' do
    it 'builds a merchant context from its preferences' do
      gateway.preferred_merchant_id = WechatPaySpecHelpers::MERCHANT_ID

      expect(gateway.merchant_context.merchant_id).to eq(WechatPaySpecHelpers::MERCHANT_ID)
    end

    # An empty row is a draft an operator can come back to. A half-filled one is
    # a mistake, and it is refused while it is still on screen rather than when
    # the first customer tries to pay.
    it 'allows a payment method with no credentials yet' do
      draft = described_class.new(store: store, name: 'WeChat Pay')
      draft.capture_method = 'checkout'

      expect(draft).to be_valid
    end

    it 'refuses a half-filled credential set' do
      gateway.capture_method = 'checkout'
      gateway.preferred_merchant_id = WechatPaySpecHelpers::MERCHANT_ID
      gateway.preferred_merchant_private_key = merchant_key_pair.to_pem
      gateway.preferred_merchant_certificate_serial = WechatPaySpecHelpers::MERCHANT_SERIAL

      expect(gateway).not_to be_valid
      expect(gateway.errors[:base].join).to include('Api v3 key')
    end

    it 'refuses public key mode without WeChat Pay’s own public key' do
      gateway.capture_method = 'checkout'
      gateway.preferred_merchant_id = WechatPaySpecHelpers::MERCHANT_ID
      gateway.preferred_merchant_private_key = merchant_key_pair.to_pem
      gateway.preferred_merchant_certificate_serial = WechatPaySpecHelpers::MERCHANT_SERIAL
      gateway.preferred_api_v3_key = WechatPaySpecHelpers::API_V3_KEY

      expect(gateway).not_to be_valid
      expect(gateway.errors[:base].join).to include('Public key pem', 'Public key id')
    end

    # Built per call: an operator who corrects a credential expects the next
    # payment to use it.
    it 'reflects a corrected credential on the next call' do
      gateway.preferred_merchant_id = '1900000001'
      first = gateway.merchant_context
      gateway.preferred_merchant_id = '1900000002'

      expect(gateway.merchant_context.merchant_id).to eq('1900000002')
      expect(first.merchant_id).to eq('1900000001')
    end

    it 'checks every answer against WeChat’s signature' do
      allow(SpreeWechatPay::Client).to receive(:new).and_call_original

      gateway.client

      expect(SpreeWechatPay::Client).to have_received(:new).with(hash_including(:verifier))
    end

    # The certificate download cannot be verified against the keys it exists to
    # fetch, so it is the one call made without a verifier.
    it 'downloads certificates with a client that does not verify them' do
      allow(SpreeWechatPay::Client).to receive(:new).and_call_original

      gateway.certificate_store

      expect(SpreeWechatPay::Client).to have_received(:new).with(hash_excluding(:verifier))
    end
  end

  describe '#credit' do
    let(:gateway) { wechat_gateway }
    let(:cart) { wechat_cart }

    let(:payment) do
      session = Spree::PaymentSessions::WechatPay.create!(
        owner: cart, payment_method: gateway, amount: cart.total, currency: 'CNY',
        status: 'pending', external_id: 'R1001-credit'
      )
      session.settle_payment!(captured: true, metadata: {})
    end

    let(:refund) { create(:refund, payment: payment, amount: 5, status: 'processing', transaction_id: nil) }

    before do
      client = instance_double(SpreeWechatPay::Client)
      allow(gateway).to receive(:client).and_return(client)
      allow(client).to receive(:post).and_return('refund_id' => 'r1', 'status' => 'PROCESSING')
    end

    it 'submits the refund against the merchant order number and returns WeChat own refund id' do
      response = gateway.credit(500, payment.response_code, originator: refund)

      expect(response).to be_success
      expect(response.authorization).to eq('r1')
      expect(gateway.client).to have_received(:post).with(
        '/v3/refund/domestic/refunds',
        hash_including('out_trade_no' => payment.response_code, 'amount' => hash_including('refund' => 500))
      )
    end

    # The refund number is the correlation key the notification and reconciliation
    # find the refund by, so it is written before the call.
    it 'writes the refund number to metadata before the call' do
      gateway.credit(500, payment.response_code, originator: refund)

      expect(refund.reload.metadata['wechat_pay_out_refund_no']).to be_present
    end

    it 'surfaces a definite rejection in WeChat own words' do
      allow(gateway.client).to receive(:post).and_raise(
        SpreeWechatPay::ApiError.new('余额不足', code: 'NOT_ENOUGH')
      )

      expect { gateway.credit(500, payment.response_code, originator: refund) }.to raise_error(
        Spree::Core::GatewayError, /余额不足/
      )
    end
  end

  # WeChat takes the money at checkout, so cancel has nothing to void — the only
  # thing it can do with a captured payment is give it back, through the one
  # refund path core owns.
  describe '#cancel' do
    let(:gateway) { wechat_gateway }
    let(:cart) { wechat_cart }

    let(:payment) do
      session = Spree::PaymentSessions::WechatPay.create!(
        owner: cart, payment_method: gateway, amount: cart.total, currency: 'CNY',
        status: 'pending', external_id: 'R1001-cancel'
      )
      session.settle_payment!(captured: true, metadata: {})
    end

    it 'answers success when there is no completed payment to settle' do
      expect(gateway.cancel('R1001-abcd1234', nil)).to be_success
    end

    it 'leaves captured money alone when the operator asked to keep it' do
      expect(Spree.refund_create_workflow).not_to receive(:call)

      expect(gateway.cancel(payment.response_code, payment, refund: false)).to be_success
    end

    it 'refunds a captured payment through the refund workflow' do
      refund = instance_double(
        Spree::Refund,
        response: Spree::PaymentResponse.new(true, nil, {}, authorization: 'refund-1')
      )
      allow(Spree.refund_create_workflow).to receive(:call).and_return(
        Spree::ServiceModule::Result.new(true, refund, nil)
      )

      expect(gateway.cancel(payment.response_code, payment)).to be_success
      expect(Spree.refund_create_workflow).to have_received(:call).with(
        hash_including(payment: payment, reason: a_kind_of(Spree::RefundReason))
      )
    end
  end

  describe '#void' do
    let(:gateway) { wechat_gateway }

    it 'answers success, because WeChat has no uncaptured authorization to release' do
      expect(gateway.void('R1001-abcd1234')).to be_success
    end
  end

  describe 'sensitive fields' do
    let(:gateway) { wechat_gateway }

    # Public key mode is the helper's default, so encryption uses the configured
    # WeChat Pay public key — the spec's `platform_key_pair` holds its private
    # half, standing in for WeChat.
    it 'encrypts a field only WeChat can read' do
      ciphertext = gateway.encrypt_sensitive_field('张三')

      expect(SpreeWechatPay::SensitiveField.decrypt(ciphertext, key: platform_key_pair)).to eq('张三')
    end

    it 'decrypts a field WeChat encrypted against the merchant certificate' do
      ciphertext = SpreeWechatPay::SensitiveField.encrypt('张三', key: merchant_key_pair.public_key)

      expect(gateway.decrypt_sensitive_field(ciphertext)).to eq('张三')
    end
  end

  # Every v3 answer is verified before it is believed, with one explicit
  # exception: the certificate download, which exists to fetch the very keys
  # verification needs. OAuth is a different host and protocol, not v3.
  #
  #   Verified    transaction create (all five scenes), query, close, refund,
  #               refund query
  #   Unverified  certificate download
  #   Not v3      OAuth access_token, OAuth jscode2session
  describe 'response verification' do
    it 'routes every payment and refund call through a verified client' do
      allow(SpreeWechatPay::Client).to receive(:new).and_call_original

      gateway.send(:transaction_for, 'R1001-abcd1234')
      gateway.send(:refund_for, 're_test-ABCDEF12')

      expect(SpreeWechatPay::Client).to have_received(:new).with(hash_including(:verifier)).twice
    end

    it 'leaves only the certificate download unverified' do
      allow(SpreeWechatPay::Client).to receive(:new).and_call_original

      gateway.certificate_store

      expect(SpreeWechatPay::Client).to have_received(:new).with(hash_excluding(:verifier)).once
    end

    it 'keeps the OAuth exchange out of the v3 client entirely' do
      allow(SpreeWechatPay::Client).to receive(:new)

      expect(gateway.send(:oauth)).to be_a(SpreeWechatPay::Oauth)
      expect(SpreeWechatPay::Client).not_to have_received(:new)
    end
  end
end
