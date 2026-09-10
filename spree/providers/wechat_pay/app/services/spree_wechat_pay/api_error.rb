module SpreeWechatPay
  # A rejection WeChat named.
  #
  # WeChat answers a rejected request with a code, a message and a JSON pointer
  # to the offending field. Those are carried through rather than flattened: a
  # merchant who configured the wrong application identifier needs to be told
  # which field is wrong, and "gateway error" tells them nothing.
  class ApiError < StandardError
    # @return [String, nil] WeChat's own error code, e.g. `OUT_TRADE_NO_USED`
    attr_reader :code
    # @return [String, nil] JSON pointer to the offending parameter
    attr_reader :field
    # @return [Integer, nil] the HTTP status WeChat answered with
    attr_reader :status

    def initialize(message, code: nil, field: nil, status: nil)
      @code = code
      @field = field
      @status = status

      detail = [code, (field && "field #{field}")].compact.join(', ')
      super(detail.present? ? "#{message} (#{detail})" : message)
    end
  end
end
