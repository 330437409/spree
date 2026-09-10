module SpreeWechatPay
  # Reconciles refunds left in `processing`, so a lost notification is not a
  # lost outcome. WeChat's own guidance is not to rely on notifications alone,
  # and its retry schedule gives up after fifteen attempts over roughly a day.
  #
  # Each stale refund is queried by its own refund number and the answer is
  # applied; a refund WeChat has no record of never happened, so its balance is
  # released for the merchant to try again.
  class ReconcileRefundsJob < BaseJob
    # How long a refund must have been processing before it is queried, so a
    # refund accepted a moment ago is not asked about before WeChat settles it.
    RECONCILE_AFTER = 5.minutes

    # A refund WeChat has no record of under this number.
    MISSING_REFUND_CODES = %w[RESOURCE_NOT_EXISTS ORDER_NOT_EXIST].freeze

    def perform
      stale_refunds.find_each { |refund| reconcile(refund) }
    end

    private

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
    rescue StandardError => error
      Rails.error.report(error, handled: true, context: { refund_id: refund.id }, source: 'spree_wechat_pay')
    end
  end
end
