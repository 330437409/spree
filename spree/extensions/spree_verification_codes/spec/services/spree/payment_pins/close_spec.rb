require 'spec_helper'

RSpec.describe Spree::PaymentPins::Close do
  let(:store) { create(:store) }
  let(:customer) { create(:customer, phone: '13800138000') }
  let!(:record) { create(:payment_pin, store: store, customer: customer, pin: '246813') }

  subject(:result) do
    described_class.call(store: store, customer: customer, pin: pin, code: code)
  end

  let(:pin) { '246813' }
  let(:code) { '123456' }

  before do
    create(:verification_code, store: store, phone: customer.phone, purpose: 'payment', code: '123456')
  end

  # Closing is not deleting: the PIN stays so the customer can turn it back on
  # without thinking up another one, and the prompt is what stops.
  it 'stops asking for the PIN and keeps it' do
    expect(result).to be_success
    expect(result.value).to eq(record)
    expect(record.reload.required).to be false
    expect(record.pin_digest).to be_present
    expect(record.deleted_at).to be_nil
  end

  it 'spends the code' do
    result

    expect(Spree::VerificationCode.usable_for(store: store, phone: customer.phone, purpose: 'payment')).to be_nil
  end

  it 'refuses without the PIN the customer has now' do
    result = described_class.call(store: store, customer: customer, pin: '999999', code: code)

    expect(result).to be_failure
    expect(result.error.value[:pay_password]).to be_present
    expect(record.reload.required).to be true
  end

  # The message is only spent by the attempt that succeeds: a mistyped PIN must
  # not cost the customer an SMS — the rule Set follows, and Close must not
  # disagree with it.
  it 'does not spend the code when the PIN is wrong' do
    described_class.call(store: store, customer: customer, pin: '999999', code: code)

    expect(Spree::VerificationCode.usable_for(store: store, phone: customer.phone, purpose: 'payment')).to be_present
    expect(described_class.call(store: store, customer: customer, pin: pin, code: code)).to be_success
  end

  # A wrong PIN is a guess at the credential, so it counts against the lockout
  # wherever it is presented.
  it 'counts a wrong PIN against the lockout' do
    described_class.call(store: store, customer: customer, pin: '999999', code: code)

    expect(record.reload.failed_attempts).to eq(1)
  end

  it 'refuses without a code' do
    result = described_class.call(store: store, customer: customer, pin: pin, code: '999999')

    expect(result).to be_failure
    expect(record.reload.required).to be true
  end

  it 'answers a missing PIN as one' do
    record.destroy

    expect(described_class.call(store: store, customer: customer, pin: pin, code: code).error.value).to eq(:pin_missing)
  end
end
