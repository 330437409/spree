require 'spec_helper'

RSpec.describe SpreeNotifications::Integration do
  subject(:integration) { create(:spree_notifications_integration, store: store) }

  let(:store) { create(:store) }
  let(:client) { instance_double(SpreeNotifications::TencentSms::Client, send_sms: { 'Code' => 'Ok' }) }

  before { allow(integration).to receive(:client).and_return(client) }

  describe 'sending' do
    it 'sends the event’s template with its parameters in order, to the number the vendor wants' do
      integration.deliver_sms(phone: '13800138000', event: 'verification_code', payload: { code: '123456', minutes: 5 })

      expect(client).to have_received(:send_sms).with(
        phone: '+8613800138000', template_id: '1234567', params: ['123456', 5], sign_name: '酒小二'
      )
    end

    it 'reads the template of the event it is sending' do
      integration.deliver_sms(phone: '13800138000', event: 'payment_pin_code', payload: { code: '999999', minutes: 5 })

      expect(client).to have_received(:send_sms).with(hash_including(template_id: '7654321'))
    end

    # A message with empty placeholders reaches the customer and helps nobody:
    # the operator has to learn the template is missing before that.
    it 'refuses an event with no approved template, naming the event' do
      expect {
        integration.deliver_sms(phone: '13800138000', event: 'invoice_resent', payload: {})
      }.to raise_error(SpreeNotifications::UndeliverableError, /invoice_resent/)
    end

    it 'names the vendor’s own refusal rather than summarizing it' do
      allow(client).to receive(:send_sms).and_raise(
        SpreeNotifications::DeliveryError.new('号码在黑名单中', code: 'FailedOperation.PhoneNumberInBlacklist')
      )

      expect {
        integration.deliver_sms(phone: '13800138000', event: 'verification_code', payload: { code: '1', minutes: 5 })
      }.to raise_error(SpreeNotifications::DeliveryError, 'FailedOperation.PhoneNumberInBlacklist: 号码在黑名单中')
    end
  end

  describe 'connecting' do
    let(:client) { instance_double(SpreeNotifications::TencentSms::Client) }

    it 'verifies the signature the account has had approved' do
      allow(client).to receive(:sign_names).and_return(['酒小二'])

      expect(integration.can_connect?).to be true
    end

    # Credentials that authenticate and a signature that was never approved
    # are an account that cannot send — worth blocking activation over.
    it 'refuses a signature this account does not have' do
      allow(client).to receive(:sign_names).and_return(['别的签名'])

      expect(integration.can_connect?).to be false
      expect(integration.connection_error_message).to include('酒小二')
    end

    it 'refuses an account with no credentials' do
      integration.preferred_secret_id = nil

      expect(integration.can_connect?).to be false
      expect(integration.connection_error_message).to be_present
    end

    # A DNS failure or a timeout must surface as an activation error, never a 500.
    it 'reports an unreachable vendor as a connection failure' do
      allow(client).to receive(:sign_names).and_raise(Faraday::ConnectionFailed.new('no route to host'))

      expect(integration.can_connect?).to be false
      expect(integration.connection_error_message).to eq('no route to host')
    end
  end
end
