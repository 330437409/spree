module Spree
  module Api
    module V3
      module Store
        # Asking for a code.
        #
        # Reachable without a session, because binding a number, resetting a
        # password and registering all happen before there is one. What guards
        # it is two buckets rather than a login: the API's own limit keyed by
        # the caller's address, and the number's own window, which is the one
        # that sees a pumping run spread across addresses
        # (docs/plans/6.1-phone-verification-and-payment-pin.md).
        class VerificationCodesController < Store::BaseController
          allow_guest_storefront_access!

          rate_limit to: Spree::Api::Config[:rate_limit_verification_send],
                     within: Spree::Api::Config[:rate_limit_window].seconds,
                     store: Rails.cache,
                     with: RATE_LIMIT_RESPONSE

          # Authentication stays optional — the door reads the customer when a
          # token is present (the PIN's codes are theirs alone) and serves a
          # guest when none is. The guest opt-out above is what opens the
          # endpoint, not skipping the lookup.

          # POST /api/v3/store/verification_codes
          #
          # Body: { phone, purpose, channel, ticket }
          def create
            return render_invalid_parameter('phone is required') if params[:phone].blank?
            return render_invalid_parameter('purpose must be one of account, payment') unless valid_purpose?
            return render_invalid_parameter('channel must be one of sms, voice') unless valid_channel?
            return render_pin_not_allowed unless pin_send_allowed?

            result = Spree::VerificationCodes::Issue.call(
              store: current_store,
              phone: params[:phone],
              purpose: purpose,
              channel: params[:channel].presence || 'sms'
            )

            return render_result_error(result) unless result.success?

            # One body for every outcome: a number with an account, one
            # without, and one that has asked too often this window. Telling
            # them apart is how this endpoint becomes a way to ask who shops
            # here, and the client counts down either way.
            render json: { sent: true }, status: :accepted
          end

          private

          # The family the client's own routes separate: every account flow
          # sends from one endpoint and the PIN from another, so the purpose is
          # what the caller asks for rather than something the payload says.
          # Defaulted to `account`, because that is what an unnamed send is.
          #
          # @return [String, nil]
          def purpose
            params[:purpose].presence || 'account'
          end

          def valid_purpose?
            Spree::VerificationCode::PURPOSES.include?(purpose)
          end

          def valid_channel?
            Spree::VerificationCode::CHANNELS.include?(params[:channel].presence || 'sms')
          end

          # The PIN's codes are for a signed-in customer's own number and
          # nobody else's: they exist to prove that whoever is spending the
          # balance holds the phone it is spent for, and an endpoint anybody
          # could aim at any number would be a way to spend this store's
          # template on strangers.
          #
          # @return [Boolean]
          def pin_send_allowed?
            return true unless purpose == 'payment'
            return false if current_user.nil?

            Spree::VerificationCode.normalize_phone(params[:phone]) ==
              Spree::VerificationCode.normalize_phone(current_user.phone)
          end

          def render_pin_not_allowed
            render_error(
              code: ErrorHandler::ERROR_CODES[:access_denied],
              message: Spree.t('verification_codes.errors.pin_code_needs_own_phone'),
              status: :forbidden
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
