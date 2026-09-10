module Spree
  module Api
    module V3
      module Webhooks
        class PaymentsController < ActionController::API
          include ActionController::RateLimiting
          include Spree::Core::ControllerHelpers::Store

          # Must render — instance_exec'd in a before_action, where only
          # render/redirect halts the chain.
          RATE_LIMIT_RESPONSE = -> {
            response.headers['Retry-After'] = '60'
            render json: { error: { code: 'rate_limit_exceeded', message: 'Too many requests' } },
                   status: :too_many_requests
          }

          rate_limit to: 120, within: 1.minute,
                     store: Rails.cache,
                     by: -> { request.remote_ip },
                     with: RATE_LIMIT_RESPONSE

          # POST /api/v3/webhooks/payments/:payment_method_id
          #
          # Verifies the webhook signature synchronously (returns 401 if invalid),
          # then enqueues async processing and returns 200 immediately.
          def create
            payment_method = current_store.payment_methods.find_by_prefix_id!(params[:payment_method_id])

            # Signature verification must be synchronous — invalid = 401
            result = payment_method.parse_webhook_event(request.raw_post, request.headers)

            # Unsupported event — acknowledge receipt
            return head :ok if result.nil?

            # Process asynchronously — gateways have timeout limits and will
            # retry on timeouts, so we must return 200 quickly.
            #
            # The gateway's own metadata travels with the job: it is what
            # identifies the payment at the provider (a charge id, a WeChat
            # transaction number), and the session records it on the payment.
            job_args = {
              payment_method_id: payment_method.id,
              action: result[:action].to_s,
              metadata: result[:metadata] || {}
            }

            if result[:refund].present?
              job_args[:refund_id] = result[:refund].id
              job_args[:refund_status] = result[:refund_status]
              job_args[:transaction_id] = result[:transaction_id]
            else
              job_args[:payment_session_id] = result[:payment_session]&.id
            end

            Spree::Payments::HandleWebhookJob.set(wait: 30.seconds).perform_later(**job_args)

            head :ok
          rescue Spree::PaymentMethod::WebhookSignatureError
            head :unauthorized
          rescue ActiveRecord::RecordNotFound
            head :not_found
          rescue StandardError => e
            Rails.error.report(e, source: 'spree.webhooks.payments')
            head :ok
          end
        end
      end
    end
  end
end
