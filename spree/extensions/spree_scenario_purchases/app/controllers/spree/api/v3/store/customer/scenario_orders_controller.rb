module Spree
  module Api
    module V3
      module Store
        module Customer
          # The customer's own purchases, which is what the mini program's
          # unpaid-goods screens list.
          class ScenarioOrdersController < ResourceController
            prepend_before_action :require_authentication!

            protected

            def model_class
              Spree::ScenarioOrder
            end

            def serializer_class
              Spree::Api::V3::ScenarioOrderSerializer
            end

            def scope
              orders = super.for_customer(current_user)
              # What a plan that sells something here asks for: its own history,
              # which is this list narrowed to the kind it registered.
              orders = orders.where(kind: params[:kind]) if params[:kind].present?

              case params[:status].presence
              when 'open' then orders.open_now
              when 'paid' then orders.with_status(:paid)
              when 'canceled' then orders.with_status(:canceled)
              when 'expired' then orders.with_status(:expired)
              else orders
              end
            end

            # A kind's own read of its purchase stays with the kind, so this
            # list is the frame's fields only.
            def apply_collection_sort(collection)
              collection.order(created_at: :desc, id: :desc)
            end
          end
        end
      end
    end
  end
end
