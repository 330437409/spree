require 'spec_helper'

RSpec.describe Spree::Api::V3::PaymentSerializer do
  let(:store) { @default_store }
  let(:payment) { create(:payment, payment_method: payment_method, amount: 10) }

  subject { described_class.new(payment, params: { store: store, currency: store.default_currency }).to_h }

  describe 'the confirm-receipt identifiers' do
    # A gateway that can answer a mini program's confirm-receipt handshake: the
    # merchant it sells under, and its own id for the transaction. The gateway
    # gem's own spec proves the WeChat side; this one proves the payload asks
    # for them without knowing which gateway it is holding.
    context 'with a gateway that answers' do
      let(:payment_method) do
        create(:check_payment_method, store: store).tap do |method|
          allow(method).to receive_messages(merchant_id: '1900000109')
          allow(method).to receive(:transaction_id_for).and_return('420000123420260920')
        end
      end

      it 'carries them beside the reference the gateway knows the order by' do
        expect(subject['merchant_id']).to eq('1900000109')
        expect(subject['gateway_transaction_id']).to eq('420000123420260920')
        expect(subject).to have_key('response_code')
      end
    end

    # Most gateways keep neither, and a client reading these has to be able to
    # tell "no handshake to make" from a value.
    context 'with a gateway that keeps neither' do
      let(:payment_method) { create(:check_payment_method, store: store) }

      it 'answers null' do
        expect(subject['merchant_id']).to be_nil
        expect(subject['gateway_transaction_id']).to be_nil
      end
    end
  end
end
