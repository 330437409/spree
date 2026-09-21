require 'spec_helper'

RSpec.describe SpreeVerificationCodes::PaymentPinVerification do
  subject(:verification) { described_class.new }

  let(:store) { create(:store) }
  let(:customer) { create(:customer, phone: '13800138000') }
  let(:order) { create(:order_with_line_items, store: store, customer: customer) }

  it 'is what the tender consults' do
    expect(Spree.payment_verifications).to include(an_instance_of(described_class))
  end

  describe '#required?' do
    it 'is not required of a customer with no PIN' do
      expect(verification.required?(order: order)).to be false
    end

    it 'is required once there is one' do
      create(:payment_pin, store: store, customer: customer, pin: '246813')

      expect(verification.required?(order: order)).to be true
    end

    # The flag is a fact about the customer's credential, never about which
    # purchase is being paid for.
    it 'is not required once the customer has turned the prompt off' do
      create(:payment_pin, store: store, customer: customer, pin: '246813', required: false)

      expect(verification.required?(order: order)).to be false
    end

    it 'reads a PIN set in another store as none at all' do
      create(:payment_pin, store: create(:store), customer: customer, pin: '246813')

      expect(verification.required?(order: order)).to be false
    end
  end

  describe '#verify' do
    before { create(:payment_pin, store: store, customer: customer, pin: '246813') }

    it 'accepts the PIN it was set with' do
      expect(verification.verify(order: order, proof: '246813')).to be_nil
    end

    it 'refuses another, in a way the client can tell apart' do
      refusal = verification.verify(order: order, proof: '999999')

      expect(refusal).to be_a(Spree::PaymentVerification::Refusal)
      expect(refusal.kind).to eq('invalid')
      expect(refusal.message).to be_present
    end

    it 'counts the guess against the lockout' do
      verification.verify(order: order, proof: '999999')

      expect(Spree::PaymentPin.find_by(store: store, customer: customer).failed_attempts).to eq(1)
    end

    it 'says so when it locks' do
      5.times { verification.verify(order: order, proof: '999999') }

      expect(verification.verify(order: order, proof: '246813').kind).to eq('locked')
    end

    # A spend that presented nothing is told to present one — which is what
    # `balance_not_password` promised it would be asked for.
    it 'asks for one rather than calling a missing proof wrong' do
      expect(verification.verify(order: order, proof: nil).kind).to eq('required')
      expect(verification.verify(order: order, proof: '').kind).to eq('required')
    end

    # Required and then absent: a row taken away between the flag being read
    # and the money moving is a refusal, not a free pass.
    it 'refuses when the PIN was removed after it was asked for' do
      Spree::PaymentPin.find_by(store: store, customer: customer).destroy

      expect(verification.verify(order: order, proof: nil).kind).to eq('required')
    end
  end
end
