require 'spec_helper'

RSpec.describe SpreeWechatPay::ReconcileRefundsJob do
  let(:gateway) { wechat_gateway }
  let(:cart) { wechat_cart }

  let(:payment) do
    session = Spree::PaymentSessions::WechatPay.create!(
      owner: cart,
      payment_method: gateway,
      amount: cart.total,
      currency: 'CNY',
      status: 'pending',
      external_id: 'R1001-reconcile'
    )
    session.settle_payment!(captured: true, metadata: {})
  end

  def stale_refund
    refund = create(:refund, payment: payment, amount: 5, status: 'processing', transaction_id: nil,
                             metadata: { 'wechat_pay_out_refund_no' => 're_test-ABCDEF12' })
    refund.update_columns(created_at: 10.minutes.ago)
    refund
  end

  describe '#perform' do
    it 'applies the query result to a stale processing refund' do
      refund = stale_refund
      allow_any_instance_of(SpreeWechatPay::Gateway).to receive(:query_refund).with('re_test-ABCDEF12').and_return(
        'refund_id' => 'r1', 'status' => 'SUCCESS', 'out_refund_no' => 're_test-ABCDEF12'
      )

      described_class.new.perform

      expect(refund.reload).to be_completed
      expect(refund.transaction_id).to eq('r1')
    end

    # A refund WeChat has no record of never happened, so its balance is
    # released for the merchant to try again.
    it 'cancels a refund WeChat has no record of' do
      refund = stale_refund
      allow_any_instance_of(SpreeWechatPay::Gateway).to receive(:query_refund).with('re_test-ABCDEF12').and_raise(
        SpreeWechatPay::ApiError.new('not found', code: 'RESOURCE_NOT_EXISTS', status: 404)
      )

      described_class.new.perform

      expect(refund.reload).to be_canceled
    end

    it 'skips a refund that is still fresh' do
      refund = create(:refund, payment: payment, amount: 5, status: 'processing', transaction_id: nil,
                               metadata: { 'wechat_pay_out_refund_no' => 're_test-ABCDEF12' })
      expect_any_instance_of(SpreeWechatPay::Gateway).not_to receive(:query_refund)

      described_class.new.perform

      expect(refund.reload).to be_processing
    end
  end
end
