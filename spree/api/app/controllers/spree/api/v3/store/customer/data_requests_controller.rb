module Spree
  module Api
    module V3
      module Store
        module Customer
          # A customer exercising their own GDPR rights: a copy of their data
          # (Art. 15) or its erasure (Art. 17).
          #
          # Erasure asks for the account password. Wiping a person's history is
          # irreversible, and an unattended session should not be enough to
          # trigger it — the same bar the account already applies to changing
          # an email address.
          class DataRequestsController < ResourceController
            include Spree::Api::V3::CurrentPasswordConfirmation

            prepend_before_action :require_authentication!

            # POST /api/v3/store/customers/me/data_requests
            def create
              return if erasure? && !erasure_certified?

              result = Spree::DataRequests::Create.call(
                store: current_store,
                customer: current_user,
                kind: requested_kind
              )

              return render_result_error(result) unless result.success?

              # 202: the request is accepted and the work happens elsewhere.
              # Answering 201 would imply the export already exists.
              render json: serialize_resource(result.value), status: :accepted
            end

            protected

            def model_class
              Spree::DataRequest
            end

            def serializer_class
              Spree.api.data_request_serializer
            end

            def set_parent
              @parent = current_user
            end

            def parent_association
              :data_requests
            end

            # A person sees their own requests and no one else's. The store
            # narrowing is restated because the parent branch of the base scope
            # replaces `for_store` with the association, and a customer is
            # global while their requests are not.
            def scope
              super.for_store(current_store).recent_first
            end

            private

            # Erasure is confirmed by the account password, or — for an account
            # that has none, which every account created through WeChat has —
            # by a code issued to the account's own phone. The same bar either
            # way: proof that whoever is asking is whoever this history
            # belongs to.
            #
            # @return [Boolean] false when the request was refused and answered
            def erasure_certified?
              if current_user.password_digest.present?
                return true if valid_current_password?

                render_current_password_invalid
                return false
              end

              # An account with no password has nothing to type here; what it
              # can show is the phone it signs in with, and whether that is
              # enough is the deployment's answer rather than this layer's.
              #
              # A number is required before the service is asked. The service
              # answers "no number is no change" for a *write*, which is right
              # there and would be a way past this bar here: an account with
              # neither password nor phone would be erased on a session alone.
              verifier = Spree::Dependencies.customer_phone_verification_service

              if verifier.nil? || current_user.phone.blank?
                # Nothing to check a code against, so the refusal is the one
                # upstream gives: an account that cannot present a password
                # cannot be erased through this route.
                render_current_password_invalid
              elsif verifier.constantize.certified?(phone: current_user.phone, code: params[:code])
                return true
              else
                render_error(
                  code: ErrorHandler::ERROR_CODES[:verification_code_invalid],
                  message: Spree.t('verification_codes.errors.cancel_needs_code'),
                  status: :unprocessable_content
                )
              end

              false
            end

            # Anything that is not an explicit erasure is a request to read —
            # the safe reading of an ambiguous parameter.
            def requested_kind
              erasure? ? Spree::DataRequest::ERASURE : Spree::DataRequest::ACCESS
            end

            def erasure?
              params[:kind].to_s == Spree::DataRequest::ERASURE
            end

          end
        end
      end
    end
  end
end
