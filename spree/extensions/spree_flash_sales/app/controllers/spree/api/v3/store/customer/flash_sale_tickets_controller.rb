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
              Spree::Api::V3::FlashSaleTicketSerializer
            end

            def scope
              Spree::FlashSaleTicket.holding.
                where(store: current_store, customer: current_user).
                order(:expires_at)
            end

            # Ordered by when each ticket lapses, and nothing is joined, so the
            # DISTINCT the base adds would buy nothing — while costing something
            # on PostgreSQL, which refuses `SELECT DISTINCT ... ORDER BY expires_at`
            # unless the ordered expression is in the select list.
            def collection_distinct?
              false
            end
          end
        end
      end
    end
  end
end
