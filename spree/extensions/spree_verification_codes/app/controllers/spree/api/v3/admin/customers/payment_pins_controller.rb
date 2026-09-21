module Spree
  module Api
    module V3
      module Admin
        module Customers
          # Support unlocking a customer who has locked themselves out of the
          # balance.
          #
          # A lockout with no way out is a support hole rather than a security
          # control, and the alternative to this route is an operator editing
          # the database. It removes the PIN rather than waiting the lockout
          # out, so the customer sets a new one — the new one cannot be guessed
          # past with the old attempts' counter behind it.
          #
          # @see Spree::PaymentPin the lockout this clears
          class PaymentPinsController < BaseController
            skip_before_action :set_resource, raise: false

            before_action :find_customer!
            before_action :find_pin!

            # DELETE /api/v3/admin/customers/:customer_id/payment_pin
            def destroy
              @pin.destroy

              head :no_content
            end

            private

            # Resolved from the id first because `find_by_prefix_id!` is a
            # class-level lookup — every tenant's customers answer it — and then
            # through the store's own customers, so a customer who has never
            # shopped here is a 404 rather than somebody whose credential
            # another store's operator can clear.
            def find_customer!
              customer = Spree.customer_class.find_by_prefix_id!(params[:customer_id])

              @customer = current_store.customers.find(customer.id)
            end

            def find_pin!
              @pin = Spree::PaymentPin.find_by!(store: current_store, customer: @customer)
            end
          end
        end
      end
    end
  end
end
