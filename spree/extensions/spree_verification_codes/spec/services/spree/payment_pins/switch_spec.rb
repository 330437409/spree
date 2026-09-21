require 'spec_helper'

RSpec.describe Spree::PaymentPins::Switch do
  let(:store) { create(:store) }
  let(:customer) { create(:customer, phone: '13800138000') }

  subject(:result) { described_class.call(store: store, customer: customer, required: required) }

  let(:required) { true }

  it 'turns the prompt off and on again' do
    record = create(:payment_pin, store: store, customer: customer, required: true)

    described_class.call(store: store, customer: customer, required: false)
    expect(record.reload.required).to be false

    described_class.call(store: store, customer: customer, required: true)
    expect(record.reload.required).to be true
  end

  it 'reads the string a form sends as a boolean' do
    record = create(:payment_pin, store: store, customer: customer, required: true)

    described_class.call(store: store, customer: customer, required: 'false')

    expect(record.reload.required).to be false
  end

  # A flag that promises a check the server cannot make is what the flag exists
  # to avoid: the client offers 去设置 in that state, and so does this.
  it 'answers a customer with no PIN as one' do
    expect(result.error.value).to eq(:pin_missing)
  end
end
