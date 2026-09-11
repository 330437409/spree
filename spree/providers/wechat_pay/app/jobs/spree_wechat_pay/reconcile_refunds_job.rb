module SpreeWechatPay
  # Reconciles refunds left in `processing`, so a lost notification is not a
  # lost outcome. WeChat's own guidance is not to rely on notifications alone,
  # and its retry schedule gives up after fifteen attempts over roughly a day.
  #
  # Each stale refund is queried by its own refund number and the answer is
  # applied; a refund WeChat has no record of never happened, so its balance is
  # released for the merchant to try again.
  class ReconcileRefundsJob < BaseJob
    include ActiveJob::Continuable

    # How long a refund must have been processing before it is queried, so a
    # refund accepted a moment ago is not asked about before WeChat settles it.
    RECONCILE_AFTER = 5.minutes

    # A refund WeChat has no record of under this number.
    MISSING_REFUND_CODES = %w[RESOURCE_NOT_EXISTS ORDER_NOT_EXIST].freeze

    # The cursor is the last refund queried, so a sweep interrupted by a deploy
    # resumes with the next one rather than asking WeChat about refunds all over
    # again. Each answer is applied to its own refund, so re-asking is harmless.
    def perform
      step :reconcile_refunds
    end

    private

    def reconcile_refunds(step)
      stale_refunds.find_each(start: step.cursor) do |refund|
        reconcile(refund)
        step.advance! from: refund.id
      end
    rescue CircuitOpenError
      # WeChat is refusing every call, so the next refund would be refused just
      # as fast and reported for nothing. The next scheduled run picks the sweep
      # up once the circuit has had time to close.
      return
    end

    def stale_refunds
      Spree::Refund.processing.
        joins(:payment).
        merge(Spree::Payment.where(payment_method_id: SpreeWechatPay::Gateway.pluck(:id))).
        where(created_at: ..RECONCILE_AFTER.ago)
    end

    def reconcile(refund)
      refund_number = refund.metadata['wechat_pay_out_refund_no']
      return if refund_number.blank?

      response = refund.payment.payment_method.query_refund(refund_number)

      refund.apply_status!(
        SpreeWechatPay::Refund::STATUS_ACTIONS[response['status']] || 'processing',
        transaction_id: response['refund_id'],
        provider_metadata: {
          'wechat_pay_refund_id' => response['refund_id'],
          'wechat_pay_refund_status' => response['status'],
          'wechat_pay_out_refund_no' => response['out_refund_no']
        }.compact_blank
      )
    rescue ApiError => error
      refund.update_columns(status: 'canceled') if MISSING_REFUND_CODES.include?(error.code)
    rescue CircuitOpenError
      raise
    rescue StandardError => error
      Rails.error.report(error, handled: true, context: { refund_id: refund.id }, source: 'spree_wechat_pay')
    end
  end
end
