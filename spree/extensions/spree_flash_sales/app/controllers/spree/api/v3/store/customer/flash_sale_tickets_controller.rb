module Spree
  module Api
    module V3
      module Store
        module Customer
          # What this customer holds and has not paid for — the list the order
          # pages show with each ticket's payment deadline.
          class FlashSaleTicketsController < ResourceController
            prepend_before_action :require_authentication!

            protected

            def model_class
              Spree::FlashSaleTicket
            end

            def serializer_class
              Spree::Api::V3::Store::FlashSaleTicketSerializer
            end

            def scope
              Spree::FlashSaleTicket.holding.
                where(store: current_store, customer: current_user).
                order(:expires_at)
            end
          end
        end
      end
    end
  end
end
