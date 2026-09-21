require 'spec_helper'

RSpec.describe Spree::VerificationCodes::Check do
  let(:store) { create(:store) }
  let(:phone) { '13800138000' }

  def issue_code(purpose: 'account', **attrs)
    create(:verification_code, store: store, phone: phone, purpose: purpose, code: '123456', **attrs)
  end

  subject(:result) { described_class.call(store: store, phone: phone, code: code, purpose: purpose) }

  let(:code) { '123456' }
  let(:purpose) { nil }

  it 'accepts the code that was sent, without spending it' do
    record = issue_code

    expect(result).to be_success
    expect(result.value).to eq(record)
    expect(record.reload.verified_at).to be_present
    expect(record.consumed_at).to be_nil
  end

  it 'refuses another code, and counts the attempt against the one that was sent' do
    record = issue_code

    result = described_class.call(store: store, phone: phone, code: '999999')

    expect(result).to be_failure
    expect(result.error.value).to eq(:invalid)
    expect(record.reload.attempts).to eq(1)
  end

  it 'refuses a code another store issued' do
    create(:verification_code, store: create(:store), phone: phone, purpose: 'account', code: '123456')

    expect(result.error.value).to eq(:expired)
  end

  it 'refuses a number nothing was sent to' do
    expect(described_class.call(store: store, phone: phone, code: '123456').error.value).to eq(:expired)
  end

  it 'refuses a code that already expired' do
    issue_code(expires_at: 1.minute.ago)

    expect(result.error.value).to eq(:expired)
  end

  it 'refuses a code that has run out of attempts' do
    record = issue_code
    store.preferred_verification_code_max_attempts.times { record.check!('000000') }

    expect(result.error.value).to eq(:expired)
  end

  it 'refuses a code that was already spent' do
    record = issue_code
    record.update!(consumed_at: Time.current)

    expect(result.error.value).to eq(:expired)
  end

  # The client posts only the number and the code — one endpoint serves every
  # flow — so a caller who does not name a family is answered either way, and
  # the family is enforced where the code is spent.
  it 'answers for either family when the caller does not name one' do
    issue_code(purpose: 'payment')

    expect(result).to be_success
  end

  it 'answers only for the family the caller named' do
    issue_code(purpose: 'payment')

    expect(described_class.call(store: store, phone: phone, code: code, purpose: 'account').error.value).to eq(:expired)
    expect(described_class.call(store: store, phone: phone, code: code, purpose: 'payment')).to be_success
  end
end
