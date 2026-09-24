module Spree
  module Api
    module V3
      # The notation this gem's payloads write money in.
      #
      # They are plain Alba resources rather than `BaseSerializer`s — a payload is
      # a reading of a model rather than a record, so it has no id to publish —
      # and that is what leaves them without core's `decimal_string`. This is its
      # twin, in one place instead of one per payload.
      module MembershipMoney
        # Plain decimal notation: `BigDecimal#to_s` on its own renders 0.06 as
        # "0.6e-1", which is not a number to print beside a currency sign.
        #
        # @param value [BigDecimal, Numeric, String, nil]
        # @return [String, nil]
        def decimal(value)
          return if value.nil?

          BigDecimal(value.to_s).to_s('F')
        end
      end
    end
  end
end
