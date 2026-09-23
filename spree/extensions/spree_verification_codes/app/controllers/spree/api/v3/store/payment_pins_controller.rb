module Spree
  module Api
    module V3
      module Store
        # The customer's own payment PIN: one row, read, written, switched and
        # closed.
        #
        # Every route needs a session, because the PIN belongs to the customer
        # rather than to the storefront. The proof a write needs is a `payment`
        # code sent to the customer's own number — the phone is the thing they
        # can be shown to hold — except for the switch, which changes nothing
        # about the credential and is what the settings page toggles.
        class PaymentPinsController < Store::BaseController
          prepend_before_action :require_authentication!

          # GET /api/v3/store/payment_pin
          def show
            render json: serializer_class.new(payment_pin, params: serializer_params).to_h
          end

          # PUT /api/v3/store/payment_pin — set or change it
          # PATCH /api/v3/store/payment_pin — the required/not switch
          #
          # The two writes the resource has are told apart by the verb the
          # client sends, which is what PUT and PATCH mean here: the whole
          # credential, or one flag on it.
          def update
            # Presence rather than `require`: `false` is a value the switch
            # takes, and in Rails a false parameter is blank.
            return render_missing_required if request.patch? && params[:required].nil?

            result = request.patch? ? switch_pin : set_pin

            render_pin_result(result)
          end

          # DELETE /api/v3/store/payment_pin
          #
          # Closes it: the prompt stops being asked for, and the customer can
          # turn it back on without thinking up another one. Both proofs are
          # required, because this is the switch that decides whether a balance
          # spend is guarded at all.
          def destroy
            result = Spree::PaymentPins::Close.call(
              store: current_store,
              customer: current_user,
              pin: params.require(:pay_password),
              code: params.require(:code)
            )

            render_pin_result(result)
          end

          private

          def set_pin
            Spree::PaymentPins::Set.call(
              store: current_store,
              customer: current_user,
              code: params.require(:code),
              pin: params.require(:pay_password),
              confirmation: params[:confirmation_password]
            )
          end

          def switch_pin
            Spree::PaymentPins::Switch.call(
              store: current_store,
              customer: current_user,
              required: params[:required]
            )
          end

          # @return [Spree::PaymentPin, nil] nil is a state the client renders,
          #   not an error: a customer with no PIN is the one who is offered
          #   the setting rather than the prompt
          def payment_pin
            @payment_pin ||= Spree::PaymentPin.find_by(store: current_store, customer: current_user)
          end

          def render_pin_result(result)
            if result.success?
              render json: serializer_class.new(result.value, params: serializer_params).to_h
            elsif result.error.value == :pin_missing
              render_pin_missing
            else
              render_result_error(result)
            end
          end

          def render_missing_required
            render_error(
              code: ErrorHandler::ERROR_CODES[:parameter_missing],
              message: Spree.t('verification_codes.errors.required_missing'),
              status: :unprocessable_content
            )
          end

          # Nothing to switch or close is a 404: the customer has no PIN, which
          # is a fact about their account rather than a fault in what they sent.
          def render_pin_missing
            render_error(
              code: ErrorHandler::ERROR_CODES[:record_not_found],
              message: Spree.t('verification_codes.errors.pin_missing'),
              status: :not_found
            )
          end

          def serializer_class
            Spree::Api::V3::Store::PaymentPinSerializer
          end
        end
      end
    end
  end
end
