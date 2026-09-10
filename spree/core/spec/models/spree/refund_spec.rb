require 'spec_helper'

describe Spree::Refund, type: :model do
  describe 'shared examples' do
    before do
      allow_any_instance_of(Spree::Refund).to receive(:amount_is_less_than_or_equal_to_allowed_amount)
    end

    it_behaves_like 'metadata'
    it_behaves_like 'lifecycle events'
  end

  describe '#amount=' do
    let(:refund) { build(:refund) }
    let(:amount) { '1,599,99' }

    before do
      allow_any_instance_of(Spree::Refund).to receive(:amount_is_less_than_or_equal_to_allowed_amount)
      refund.amount = amount
    end

    it 'is expected to equal to localized number' do
      expect(refund.amount).to eq(Spree::LocalizedNumber.parse(amount))
    end
  end

  describe '#perform!' do
    subject { refund.perform! }

    let(:refund) { create(:refund, payment: payment, amount: amount, reason: refund_reason, transaction_id: nil) }

    let(:amount) { 100.0 }
    let(:amount_in_cents) { amount * 100 }

    let(:authorization) { generate(:refund_transaction_id) }

    let(:payment) { create(:payment, amount: payment_amount, payment_method: payment_method) }
    let(:payment_amount) { amount * 2 }
    let(:payment_method) { create(:credit_card_payment_method) }

    let(:refund_reason) { create(:refund_reason) }

    let(:gateway_response) do
      Spree::PaymentResponse.new(
        gateway_response_success,
        gateway_response_message,
        gateway_response_params,
        gateway_response_options
      )
    end
    let(:gateway_response_success) { true }
    let(:gateway_response_message) { '' }
    let(:gateway_response_params) { {} }
    let(:gateway_response_options) { { authorization: authorization } }

    before do
      allow(payment.payment_method).
        to receive(:credit).
        with(amount_in_cents, payment.source, payment.transaction_id, originator: an_instance_of(Spree::Refund)).
        and_return(gateway_response)
    end

    it 'is never attempted by creation alone' do
      expect(payment.payment_method).not_to receive(:credit)

      refund
    end

    context 'when the refund was already credited' do
      let(:refund) { create(:refund, payment: payment, amount: amount, reason: refund_reason, transaction_id: '12kfjas0') }

      it 'does not attempt to process a transaction' do
        expect(payment.payment_method).not_to receive(:credit)

        subject
      end

      it 'maintains the transaction id' do
        subject
        expect(refund.reload.transaction_id).to eq '12kfjas0'
      end
    end

    context 'processing is successful' do
      # Creation no longer credits, so the count and return-value examples moved
      # to the workflow spec; the instrumentation belongs with the call itself.
      it 'instruments the credit gateway call as gateway.spree_payments' do
        notifications = []
        subscriber = ActiveSupport::Notifications.subscribe('gateway.spree_payments') do |*, payload|
          notifications << payload
        end

        subject

        expect(notifications.sole).to include(action: 'credit', payment_method_type: payment_method.type)
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end

      it 'saves the returned authorization value' do
        subject
        expect(refund.reload.transaction_id).to eq authorization
      end

      it 'attempts to process a transaction' do
        expect(payment.payment_method).to receive(:credit).once

        subject
      end

      it 'recalculates order totals' do
        refund
        expect { subject }.to change { payment.order.reload.updated_at }
      end
    end

    context 'processing fails' do
      let(:gateway_response_success) { false }
      let(:gateway_response_message) { 'failure message' }

      it 'raises and leaves the refund uncredited for the caller to handle' do
        expect { subject }.to raise_error(Spree::Core::GatewayError, gateway_response_message)

        expect(refund.reload.transaction_id).to be_nil
      end
    end

    context 'without payment profiles supported' do
      before do
        allow(payment.payment_method).to receive(:payment_profiles_supported?).and_return(false)
      end

      it 'does not supply the payment source' do
        expect(payment.payment_method).
          to receive(:credit).
          with(amount * 100, payment.transaction_id, originator: an_instance_of(Spree::Refund)).
          and_return(gateway_response)

        subject
      end
    end

    context 'with payment profiles supported' do
      before do
        allow(payment.payment_method).to receive(:payment_profiles_supported?).and_return(true)
      end

      it 'supplies the payment source' do
        expect(payment.payment_method).
          to receive(:credit).
          with(amount_in_cents, payment.source, payment.transaction_id, originator: an_instance_of(Spree::Refund)).
          and_return(gateway_response)

        subject
      end
    end

    context 'with a gateway connection error' do
      before do
        expect(payment.payment_method).to receive(:credit).with(
          amount_in_cents,
          payment.source,
          payment.transaction_id,
          originator: an_instance_of(Spree::Refund)
        ).and_raise(Spree::PaymentConnectionError.new('gateway_error'))
      end

      it 'raises Spree::Core::GatewayError' do
        expect { subject }.to raise_error(Spree::Core::GatewayError, Spree.t(:unable_to_connect_to_gateway))
      end
    end

    context 'with amount too large' do
      let(:payment_amount) { 10 }
      let(:amount) { payment_amount * 2 }

      it 'refuses to create the refund' do
        expect { refund }.to raise_error { |error|
          expect(error).to be_a(ActiveRecord::RecordInvalid)
          expect(error.record.errors.full_messages).to eq ["Amount #{I18n.t('activerecord.errors.models.spree/refund.attributes.amount.greater_than_allowed')}"]
        }
      end
    end
  end

  describe 'status' do
    it 'defaults a new refund to completed' do
      expect(build(:refund).status).to eq('completed')
    end
  end

  describe '.holding_balance' do
    let(:payment) { create(:payment, amount: 100, status: 'completed') }

    it 'keeps refunds that still reserve their amount' do
      processing = create(:refund, payment: payment, amount: 10, status: 'processing')
      completed = create(:refund, payment: payment, amount: 10, status: 'completed')

      expect(described_class.holding_balance).to contain_exactly(processing, completed)
    end

    it 'drops a refund the gateway canceled' do
      canceled = create(:refund, payment: payment, amount: 10, status: 'canceled')

      expect(described_class.holding_balance).not_to include(canceled)
    end

    # The only way to reach a NULL is a row written outside the model, and
    # counting it as released would let the same amount be refunded twice.
    it 'treats a row written outside the model as still holding balance' do
      refund = create(:refund, payment: payment, amount: 10)
      refund.update_column(:status, nil)

      expect(described_class.holding_balance).to include(refund)
    end
  end

  describe '#return_line_items' do
    subject { refund.return_line_items }

    let(:refund) { create(:refund, amount: 10, originator: originator) }

    context 'when the refund came from a return' do
      let(:originator) { create(:received_return) }

      it { is_expected.to match_array(originator.return_line_items) }
    end

    context 'when the refund was issued manually' do
      let(:originator) { nil }

      it { is_expected.to eq([]) }
    end
  end

  describe '#apply_status!' do
    subject(:apply) { refund.apply_status!(target_status, transaction_id: transaction_id, provider_metadata: provider_metadata) }

    let(:payment) { create(:payment, amount: 200, payment_method: create(:credit_card_payment_method)) }
    let(:refund) { create(:refund, payment: payment, amount: 10, status: 'processing', transaction_id: nil) }
    let(:target_status) { 'completed' }
    let(:transaction_id) { 'refund-123' }
    let(:provider_metadata) { { 'provider_status' => 'SUCCESS' } }

    it 'moves a processing refund to a terminal status' do
      apply

      expect(refund.reload).to be_completed
    end

    it 'records the gateway refund reference when it was missing' do
      apply

      expect(refund.reload.transaction_id).to eq('refund-123')
    end

    it 'keeps the provider detail verbatim in metadata' do
      apply

      expect(refund.reload.metadata['provider_status']).to eq('SUCCESS')
    end

    it 'does not move a refund that already reached a terminal status' do
      refund.update!(status: 'completed', transaction_id: 'refund-123')

      expect { apply }.not_to change { refund.reload.status }
    end

    it 'leaves a non-terminal report in processing' do
      refund.apply_status!('processing', transaction_id: 'refund-123', provider_metadata: { 'provider_status' => 'ABNORMAL' })

      expect(refund.reload).to be_processing
      expect(refund.transaction_id).to eq('refund-123')
      expect(refund.metadata['provider_status']).to eq('ABNORMAL')
    end

    it 'does not move a canceled refund to completed' do
      refund.update!(status: 'canceled', transaction_id: 'refund-123')

      apply

      expect(refund.reload).to be_canceled
    end
  end
end
