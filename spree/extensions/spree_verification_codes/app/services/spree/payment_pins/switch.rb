module Spree
  module PaymentPins
    # The required/not switch: whether a balance spend asks for the PIN a
    # customer already has.
    #
    # Turning it on with no PIN to ask for is refused rather than stored — the
    # client offers 去设置 in that state, and a flag that promises a check the
    # server cannot make is what the flag exists to avoid.
    class Switch
      prepend Spree::ServiceModule::Base

      # @param store [Spree::Store]
      # @param customer [Object]
      # @param required [Boolean]
      # @return [Spree::ServiceModule::Result] value is the PIN row
      def call(store:, customer:, required:)
        record = Spree::PaymentPin.find_by(store: store, customer: customer)
        return failure(nil, :pin_missing) if record.nil?

        record.required = ActiveModel::Type::Boolean.new.cast(required)
        return failure(record) unless record.save

        success(record)
      end
    end
  end
end
