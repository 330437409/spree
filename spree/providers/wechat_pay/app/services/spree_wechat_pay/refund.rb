module SpreeWechatPay
  # WeChat refund operations, addressed by our merchant refund number.
  #
  # The refund API is a different path from the transaction API and its result
  # is what the refund status matrix maps onto Spree's canonical statuses, so it
  # lives beside {SpreeWechatPay::Transaction} rather than inside it.
  class Refund
    # WeChat's `refund_status` mapped onto Spree's canonical statuses. `ABNORMAL`
    # is deliberately not terminal — the money could still reach the customer —
    # so it stays `processing`; only `SUCCESS` and `CLOSED` move a refund out of
    # `processing`.
    STATUS_ACTIONS = {
      'SUCCESS' => 'completed',
      'CLOSED' => 'canceled',
      'ABNORMAL' => 'processing',
      'PROCESSING' => 'processing'
    }.freeze

    REFUND_PATH = '/v3/refund/domestic/refunds'.freeze

    # @param context [SpreeWechatPay::MerchantContext]
    # @param client [SpreeWechatPay::Client]
    # @param merchant_refund_number [String] our `out_refund_no`
    def initialize(context:, client:, merchant_refund_number:)
      @context = context
      @client = client
      @merchant_refund_number = merchant_refund_number
    end

    # Submits the refund. WeChat's answer is acceptance, not completion — the
    # outcome arrives by notification or query.
    #
    # @param payload [Hash]
    # @return [Hash] carries `refund_id` and the refund's current `status`
    def create(payload)
      @client.post(REFUND_PATH, payload)
    end

    # @return [Hash] the refund as WeChat sees it
    # @raise [SpreeWechatPay::ApiError] `RESOURCE_NOT_EXISTS` when nothing was
    #   ever created under this number
    def query
      @client.get("#{REFUND_PATH}/#{CGI.escape(@merchant_refund_number)}")
    end
  end
end
