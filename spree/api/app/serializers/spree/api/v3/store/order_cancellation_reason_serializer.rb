module Spree
  module Api
    module V3
      module Store
        # One of the merchant's reasons for calling an order off, as a customer
        # picking one needs it: what to show and what to send back.
        class OrderCancellationReasonSerializer < BaseSerializer
          typelize name: :string

          attributes :name
        end
      end
    end
  end
end
