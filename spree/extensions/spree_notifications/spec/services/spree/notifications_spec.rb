require 'spec_helper'

RSpec.describe Spree::Notifications do
  let(:store) { create(:store) }
  let(:customer) { create(:customer, phone: '13800138000') }

  # Activation verifies the account against the vendor, and a spec must not
  # reach Tencent — the credentials here are nobody's.
  let(:integration) { create(:spree_notifications_integration, store: store) }

  describe 'the event vocabulary' do
    it 'names every consumer of the plan set' do
      expect(described_class::EVENTS.keys).to contain_exactly(
        'verification_code', 'payment_pin_code',
        'invitation_reminder', 'invoice_resent', 'dispatch_failed', 'seckill_reminder'
      )
    end

    it 'names the channel and the template parameters of a code' do
      expect(described_class::EVENTS['verification_code']).to eq(channel: 'sms', params: %w[code minutes])
    end

    it 'leaves the events whose consumers have not landed without a channel' do
      expect(described_class::EVENTS['invoice_resent'][:channel]).to be_nil
    end
  end

  describe '.deliver' do
    it 'enqueues the send rather than performing it' do
      expect { described_class.deliver(to: customer, event: 'verification_code', payload: { code: '123456' }, store: store) }
        .to have_enqueued_job(Spree::Notifications::DeliverJob)
    end

    it 'carries the store, because a job is not in a request' do
      described_class.deliver(to: customer, event: 'verification_code', store: store)

      expect(Spree::Notifications::DeliverJob).to have_been_enqueued.with(
        hash_including(to: customer, event: 'verification_code', store: store)
      )
    end

    it 'refuses an event nobody declared' do
      allow(Rails.error).to receive(:report)

      described_class.deliver_now(to: customer, event: 'marketing_blast', store: store)

      expect(Rails.error).to have_received(:report).with(
        instance_of(SpreeNotifications::UndeliverableError), handled: true, context: { event: 'marketing_blast' }
      )
    end

    it 'refuses an event whose consumer has not landed' do
      allow(Rails.error).to receive(:report)

      described_class.deliver_now(to: customer, event: 'invoice_resent', store: store)

      expect(Rails.error).to have_received(:report).with(
        instance_of(SpreeNotifications::UndeliverableError), handled: true, context: { event: 'invoice_resent' }
      )
    end

    it 'refuses a recipient the channel cannot reach' do
      integration.update_column(:active, true)
      allow(Rails.error).to receive(:report)

      described_class.deliver_now(to: 'nobody', event: 'verification_code', store: store)

      expect(Rails.error).to have_received(:report).with(
        instance_of(SpreeNotifications::UndeliverableError), handled: true, context: { event: 'verification_code' }
      )
    end

    it 'never reports the recipient — a phone number is somebody’s' do
      allow(Rails.error).to receive(:report)

      described_class.deliver_now(to: '13800138000', event: 'invoice_resent', store: store)

      expect(Rails.error).to have_received(:report) do |_error, **options|
        expect(options[:context].values).not_to include('13800138000')
      end
    end
  end

  # ActiveJob logs every job's arguments, and one of them is a verification
  # code in clear.
  describe 'the delivery job' do
    it 'never logs its arguments' do
      expect(Spree::Notifications::DeliverJob.log_arguments?).to be false
    end
  end

  describe '.params_for' do
    it 'reads the event’s parameters in the order its template numbers them' do
      expect(described_class.params_for('verification_code', { code: '123456', minutes: 5 })).to eq(['123456', 5])
    end
  end
end
