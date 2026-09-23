module Spree
  module Api
    module V3
      module Store
        # Proving a code without spending it.
        #
        # A creation rather than an action on a resource, because that is what
        # it is: the check either succeeds or fails, and the client then posts
        # the same code to the write that needs the proof. Nothing is consumed
        # here — the write consumes — so a customer who checks a code and then
        # abandons the form has not burned it
        # (docs/plans/6.1-phone-verification-and-payment-pin.md).
        class VerificationChecksController < Store::BaseController
          allow_guest_storefront_access!

          # A check is a bcrypt comparison per accepted request, on an endpoint
          # a guest can reach: without a ceiling of its own the only bound on
          # unauthenticated hashing would be the API's blanket budget. It
          # shares the send's preference because the two are one flow.
          rate_limit to: Spree::Api::Config[:rate_limit_verification_send],
                     within: Spree::Api::Config[:rate_limit_window].seconds,
                     store: Rails.cache,
                     with: RATE_LIMIT_RESPONSE

          # Authentication stays optional — the door reads the customer when a
          # token is present (the PIN's codes are theirs alone) and serves a
          # guest when none is. The guest opt-out above is what opens the
          # endpoint, not skipping the lookup.

          # POST /api/v3/store/verification_checks
          #
          # Body: { phone, code, purpose }
          def create
            return render_invalid_parameter(Spree.t('verification_codes.errors.phone_and_code_required')) if params[:phone].blank? || params[:code].blank?

            result = Spree::VerificationCodes::Check.call(
              store: current_store,
              phone: params[:phone],
              code: params[:code],
              purpose: params[:purpose].presence
            )

            return render_check_error(result.error.value) unless result.success?

            render json: serializer_class.new(result.value, params: serializer_params).to_h
          end

          private

          def serializer_class
            Spree::Api::V3::VerificationCheckSerializer
          end

          # Two answers the client shows differently: there is nothing left to
          # check (a code that expired, was already spent, or ran out of
          # attempts) as against a code that simply did not match. Both count
          # the attempt, so a caller who guesses cannot tell the two apart by
          # watching the counter.
          #
          # @param reason [Symbol]
          def render_check_error(reason)
            expired = reason == :expired

            render_error(
              code: expired ? ErrorHandler::ERROR_CODES[:verification_code_expired] : ErrorHandler::ERROR_CODES[:verification_code_invalid],
              message: Spree.t("verification_codes.errors.code_#{reason}"),
              status: :unprocessable_content
            )
          end

          def render_invalid_parameter(message)
            render_error(
              code: ErrorHandler::ERROR_CODES[:parameter_invalid],
              message: message,
              status: :unprocessable_content
            )
          end
        end
      end
    end
  end
end
