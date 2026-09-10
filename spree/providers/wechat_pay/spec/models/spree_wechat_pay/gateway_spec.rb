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

    # WeChat does settle a refund after accepting it, but advertising that
    # before a refund API exists leaves a `processing` refund reserving the
    # payment's balance with nothing able to resolve it.
    it 'does not claim asynchronous refunds before refunds are implemented' do
      expect(gateway.async_refunds?).to be false
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

  describe 'credentials' do
    it 'builds a merchant context from its preferences' do
      gateway.preferred_merchant_id = WechatPaySpecHelpers::MERCHANT_ID

      expect(gateway.merchant_context.merchant_id).to eq(WechatPaySpecHelpers::MERCHANT_ID)
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
end
