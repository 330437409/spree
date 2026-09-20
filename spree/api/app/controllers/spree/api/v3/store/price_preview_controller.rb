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
          include Spree::Api::V3::CartResolvable

          # POST /api/v3/store/price_preview
          #
          # Two ways to ask the same question: a set of variants, before anything
          # exists, or a cart, at the settle page. A cart carries its own context,
          # so its lines are priced in its currency and by the sources it is
          # already holding.
          def create
            cart = find_cart if params[:cart_id].present?
            return if performed?

            items = cart ? cart_items(cart) : resolved_items
            return if performed?

            # Resolved before the sources run: what they do is a write, and a
            # warehouse this store does not have must refuse the request rather
            # than leave a cart priced by a request that failed.
            stock_location = stock_location_param

            # A source that has to write what it prices does it here, where the
            # request has told it everything it needs. The preview is a
            # computation rather than a resource, and this is the write it owns.
            apply_sources(cart) if cart

            result = Spree::PricePreview.call(
              items: items, currency: cart&.currency, customer: current_user,
              context: source_context, stock_location: stock_location
            )

            render json: serializer_class.new(result.value, params: serializer_params).to_h
          end

          private

          # Every line the cart holds: the tick that chooses some of them is the
          # cart's own state, and selecting them is not built yet.
          def cart_items(cart)
            cart.line_items.map do |line_item|
              { variant: line_item.variant, quantity: line_item.quantity }
            end
          end

          def apply_sources(cart)
            Spree.price_preview_sources.each do |source|
              source.apply!(cart: cart, customer: current_user) if source.respond_to?(:apply!)
            end
          end

          def serializer_class
            Spree::Api::V3::Store::PricePreviewSerializer
          end

          def permitted_params
            params.permit(:currency, items: [:variant_id, :quantity], context: {})
          end

          # What a registered source needs to price a line — an activity's id,
          # a ticket's. Passed through untouched, because the route serves every
          # source rather than the one this application happens to have.
          def source_context
            permitted_params[:context].to_h.symbolize_keys
          end

          # The warehouse an area page is about, when it names one. Read through
          # the store's own active locations: an id from another tenant, or one
          # for a warehouse the operator has parked, is a 404 rather than a
          # figure that contradicts the goods' own availability beside it.
          # @return [Spree::StockLocation, nil]
          def stock_location_param
            id = params[:stock_location_id]
            return nil if id.blank?

            current_store.stock_locations.active.find_by_prefix_id!(id)
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
