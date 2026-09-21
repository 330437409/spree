require 'spec_helper'

RSpec.describe Spree::NotificationChannels::Sms do
  subject(:channel) { described_class.new }

  let(:store) { create(:store) }
  let(:payload) { { code: '123456', minutes: 5 } }

  describe 'whether it can reach somebody' do
    it 'answers for a customer with a Chinese mobile' do
      expect(channel.available_for?(create(:customer, phone: '13800138000'))).to be true
    end

    # A code goes to the number being changed to, which belongs to nobody yet.
    it 'answers for a number that is not a record at all' do
      expect(channel.available_for?('13800138000')).to be true
    end

    it 'does not answer for a customer with no phone' do
      expect(channel.available_for?(create(:customer, phone: nil))).to be false
    end

    it 'does not answer for a number that is not a mobile' do
      expect(channel.available_for?('555-1234')).to be false
    end

    it 'reads a stored number as digits without a country code' do
      expect(channel.phone_for('+86 138-0013-8000')).to eq('13800138000')
    end

    it 'leaves a number that only looks Chinese-numbered alone' do
      expect(channel.phone_for('1234567890')).to eq('1234567890')
    end
  end

  describe 'sending' do
    # Activated by column: activation verifies the account against the vendor,
    # and these credentials are nobody's.
    let(:integration) { create(:spree_notifications_integration, store: store).tap { |row| row.update_column(:active, true) } }

    before { allow(channel).to receive(:integration_for).with(store).and_return(integration) }

    it 'hands the message to the store’s own account, with the number normalized' do
      allow(integration).to receive(:client).and_return(instance_double(SpreeNotifications::TencentSms::Client, send_sms: { 'Code' => 'Ok' }))

      channel.deliver(recipient: '13800138000', event: 'verification_code', payload: payload, store: store)

      expect(integration.client).to have_received(:send_sms).with(
        phone: '+8613800138000', template_id: '1234567',
        params: ['123456', 5], sign_name: '酒小二'
      )
    end

    # A store with no account is a merchant nobody has onboarded yet, not a
    # customer who did something wrong.
    it 'reports a store with no account rather than failing silently' do
      allow(channel).to receive(:integration_for).with(store).and_return(nil)
      allow(Rails.error).to receive(:report)

      channel.deliver(recipient: '13800138000', event: 'verification_code', payload: payload, store: store)

      expect(Rails.error).to have_received(:report).with(
        instance_of(SpreeNotifications::UndeliverableError), handled: true, context: { event: 'verification_code' }
      )
    end

    # The code row already exists and the customer can ask for another; a
    # second attempt would be a second message.
    it 'reports a vendor refusal instead of raising at the caller' do
      allow(integration).to receive(:client).and_raise(SpreeNotifications::DeliveryError.new('refused', code: 'FailedOperation'))
      allow(Rails.error).to receive(:report)

      expect {
        channel.deliver(recipient: '13800138000', event: 'verification_code', payload: payload, store: store)
      }.not_to raise_error

      expect(Rails.error).to have_received(:report).with(
        instance_of(SpreeNotifications::DeliveryError), handled: true, context: hash_including(event: 'verification_code')
      )
    end
  end
end
