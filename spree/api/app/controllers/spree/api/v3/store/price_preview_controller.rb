module Spree
  module Api
    module V3
      module Store
        # What a basket of goods would cost, without a cart.
        #
        # It is a computation rather than a resource, so it is written rather
        # than read: the product page posts the variants it is showing, and the
        # settlement page posts the same shape with a cart once there is one.
        # There is exactly one of it — a plan that needs another field adds it
        # here rather than opening a second price calculation.
        class PricePreviewController < Store::BaseController
          # POST /api/v3/store/price_preview
          def create
            items = resolved_items
            return if performed?

            result = Spree::PricePreview.call(items: items, customer: current_user)

            render json: serializer_class.new(result.value, params: serializer_params).to_h
          end

          private

          def serializer_class
            Spree::Api::V3::Store::PricePreviewSerializer
          end

          def permitted_params
            params.permit(:currency, items: [:variant_id, :quantity])
          end

          # Every variant is read through the store's own products, narrowed the
          # way the product read narrows them — an id from another tenant, or of
          # a product this storefront does not show, is a 404 rather than a price.
          #
          # @return [Array<Hash>]
          def resolved_items
            requested = items_param
            return [] if performed?

            requested.map do |item|
              { variant: variant_scope.find_by_prefix_id!(item[:variant_id]),
                quantity: quantity_param(item) }
            end
          end

          # A payload that is not a list of items is a request to fix, not a
          # crash: `items: {}` would otherwise raise on the way to the service.
          def items_param
            items = params[:items]

            if !items.is_a?(Array) || items.empty?
              render_invalid_preview('items must be a non-empty array of { variant_id, quantity }')
              return []
            end

            items
          end

          def quantity_param(item)
            quantity = item[:quantity].presence || 1

            unless quantity.to_s.match?(/\A[1-9]\d*\z/)
              render_invalid_preview('quantity must be a positive whole number')
            end

            quantity.to_i
          end

          def render_invalid_preview(message)
            render_error(
              code: ErrorHandler::ERROR_CODES[:validation_error],
              message: message,
              status: :unprocessable_content
            )
          end

          def variant_scope
            Spree::Variant.where(product_id: product_scope.select(:id))
          end

          def product_scope
            @product_scope ||= begin
              published = current_store.products.available(
                Time.current, Spree::Current.currency, include_preorderable: true
              )

              Spree.products_for_context_service.call(
                store: current_store, channel: current_channel, customer: current_user, base: published
              ).value
            end
          end
        end
      end
    end
  end
end
