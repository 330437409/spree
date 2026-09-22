module Spree
  module Api
    module V3
      module Store
        # Buying something that is not an order.
        #
        # One create for every scenario and every channel, because they differ
        # in what the kind prices and issues rather than in shape: the plan that
        # owns the entitlement registers a kind, and this endpoint asks it.
        class ScenarioOrdersController < ResourceController
          prepend_before_action :require_authentication!

          # A purchase is created through its kind's own pricing, so the service
          # is the workflow and the base class keeps the rendering.
          def create_workflow
            Spree::ScenarioOrders::Create
          end

          def create_workflow_arguments
            {
              kind: params[:kind],
              store: current_store,
              customer: current_user,
              channel: params[:channel].presence,
              context: context,
              external_data: external_data
            }
          end

          protected

          def model_class
            Spree::ScenarioOrder
          end

          def serializer_class
            Spree::Api::V3::Store::ScenarioOrderSerializer
          end

          # A customer reads and removes their own purchases; another customer's
          # is not here at all.
          def scope
            super.for_customer(current_user)
          end

          def apply_collection_sort(collection)
            collection.order(created_at: :desc, id: :desc)
          end

          private

          # What the kind was told. It is the kind's own vocabulary, so the
          # frame passes it through rather than validating a shape it does not
          # know.
          def context
            (params[:context] || {}).to_unsafe_h
          end

          # What the gateway needs beyond the amount: the scene the customer is
          # paying in — the mini program unless the caller says otherwise — and
          # whatever that scene carries, which is the WeChat authorization code
          # today.
          def external_data
            {
              'scene' => params[:scene].presence || 'mini_program',
              'code' => params[:code].presence,
              'payer_client_ip' => request.remote_ip
            }.compact
          end
        end
      end
    end
  end
end
