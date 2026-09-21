require 'spec_helper'

RSpec.describe Spree::PaymentPins::Set do
  let(:store) { create(:store) }
  let(:customer) { create(:customer, phone: '13800138000') }
  let(:code) { '123456' }

  subject(:result) do
    described_class.call(store: store, customer: customer, code: code, pin: pin, confirmation: confirmation)
  end

  let(:pin) { '246813' }
  let(:confirmation) { '246813' }

  def send_code(purpose: 'payment', value: '123456')
    create(:verification_code, store: store, phone: customer.phone, purpose: purpose, code: value)
  end

  it 'sets the PIN with a code sent to the customer’s own number' do
    record = send_code

    expect(result).to be_success
    expect(result.value.pin_digest).to be_present
    expect(result.value.verify('246813')).to be(true).or be_truthy
    expect(record.reload.consumed_at).to be_present
  end

  it 'asks for it by default: a PIN that did not exist is one to be used' do
    send_code

    expect(result.value.required).to be true
  end

  it 'refuses a code that does not match, and keeps the code' do
    record = send_code

    result = described_class.call(store: store, customer: customer, code: '999999', pin: pin)

    expect(result).to be_failure
    expect(result.error.value[:code]).to be_present
    expect(record.reload.consumed_at).to be_nil
  end

  # A PIN the server refuses must not cost the customer a message.
  it 'refuses a PIN that is too simple without spending the code' do
    record = send_code

    result = described_class.call(store: store, customer: customer, code: code, pin: '111111')

    expect(result).to be_failure
    expect(result.error.value[:pin]).to be_present
    expect(record.reload.consumed_at).to be_nil
  end

  it 'refuses a confirmation that does not match' do
    send_code

    result = described_class.call(store: store, customer: customer, code: code, pin: pin,
                                  confirmation: '111222')

    expect(result).to be_failure
    expect(result.error.value[:pin_confirmation]).to be_present
  end

  # The family is what keeps a code sent for an account flow out of the PIN.
  it 'refuses a code issued for the account flows' do
    send_code(purpose: 'account')

    expect(result).to be_failure
    expect(result.error.value[:code]).to be_present
  end

  it 'changes an existing PIN and leaves the customer’s own switch alone' do
    send_code(value: '123456')
    described_class.call(store: store, customer: customer, code: '123456', pin: '246813')
    Spree::PaymentPin.find_by(store: store, customer: customer).update!(required: false)

    send_code(value: '654321')
    result = described_class.call(store: store, customer: customer, code: '654321', pin: '135791')

    expect(result).to be_success
    expect(result.value.required).to be false
    expect(result.value.verify('135791')).to be_truthy
  end

  # Closing keeps the row, and the unique index counts it either way — so a
  # customer who comes back restores theirs rather than colliding with it.
  it 're-opens a PIN that was closed' do
    send_code
    described_class.call(store: store, customer: customer, code: '123456', pin: '246813')
    Spree::PaymentPin.find_by(store: store, customer: customer).destroy

    send_code(value: '222222')
    result = described_class.call(store: store, customer: customer, code: '222222', pin: '135791')

    expect(result).to be_success
    expect(Spree::PaymentPin.count).to eq(1)
  end
end
