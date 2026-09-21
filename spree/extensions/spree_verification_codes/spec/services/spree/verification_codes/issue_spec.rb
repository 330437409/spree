require 'spec_helper'

RSpec.describe Spree::VerificationCodes::Issue do
  let(:store) { create(:store) }
  let(:phone) { '13800138000' }

  subject(:result) { described_class.call(store: store, phone: phone, purpose: purpose, channel: channel) }

  let(:purpose) { 'account' }
  let(:channel) { 'sms' }

  # The number's window lives in the cache, and the test environment's store
  # is not one that keeps anything: a spec about counting needs one that does.
  around do |example|
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = original
  end

  it 'leaves a code the number can be proved with' do
    expect(result).to be_success
    expect(result.value).to be_persisted
    expect(result.value.phone).to eq(phone)
    expect(result.value.purpose).to eq('account')
  end

  it 'keeps a digest rather than the code' do
    record = result.value

    expect(record.code_digest).to be_present
    expect(record.authenticate_code(record.code)).to be_truthy
  end

  it 'takes its window from the store rather than a constant' do
    store.update!(preferred_verification_code_ttl_minutes: 9)

    expect(result.value.expires_at).to be_within(5.seconds).of(9.minutes.from_now)
  end

  it 'normalizes the number it stores' do
    expect(described_class.call(store: store, phone: '+86 138-0013-8000', purpose: 'account').value.phone)
      .to eq(phone)
  end

  it 'refuses without a number to send to' do
    expect(described_class.call(store: store, phone: '', purpose: 'account').error.value).to eq(:phone_missing)
  end

  describe 'the message' do
    it 'enqueues it through the platform sender, with the code and its window' do
      expect { result }.to have_enqueued_job(Spree::Notifications::DeliverJob)

      expect(Spree::Notifications::DeliverJob).to have_been_enqueued.with(
        hash_including(
          to: phone,
          event: 'verification_code',
          payload: { code: result.value.code, minutes: store.preferred_verification_code_ttl_minutes },
          store: store
        )
      )
    end

    # The PIN's codes are their own event, because they are their own template.
    it 'names the PIN’s own event for a payment code' do
      described_class.call(store: store, phone: phone, purpose: 'payment')

      expect(Spree::Notifications::DeliverJob).to have_been_enqueued.with(hash_including(event: 'payment_pin_code'))
    end
  end

  describe 'the number’s own window' do
    it 'stops sending after three in ten minutes' do
      3.times { described_class.call(store: store, phone: phone, purpose: 'account') }

      expect { described_class.call(store: store, phone: phone, purpose: 'account') }
        .not_to change(Spree::VerificationCode, :count)
      expect(Spree::Notifications::DeliverJob).to have_been_enqueued.exactly(3).times
    end

    # One number's bill, however many addresses ask for it.
    it 'counts the window per number, not per caller' do
      3.times { described_class.call(store: store, phone: phone, purpose: 'account') }

      expect { described_class.call(store: store, phone: '13900139000', purpose: 'account') }
        .to change(Spree::VerificationCode, :count).by(1)
    end

    # The caller is told nothing: whoever asked cannot learn from this answer
    # that the number has been asked about recently.
    it 'answers as if it had sent' do
      3.times { described_class.call(store: store, phone: phone, purpose: 'account') }

      silent = described_class.call(store: store, phone: phone, purpose: 'account')

      expect(silent).to be_success
      expect(silent.value).to be_nil
    end
  end
end
