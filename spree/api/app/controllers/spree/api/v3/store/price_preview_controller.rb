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

          # Every variant is read through the store's own products, so an id
          # belonging to another tenant is a 404 rather than a price.
          #
          # @return [Array<Hash>]
          def resolved_items
            permitted_params[:items].to_a.map do |item|
              { variant: variant_scope.find_by_prefix_id!(item[:variant_id]),
                quantity: item[:quantity].presence || 1 }
            end
          end

          def variant_scope
            Spree::Variant.where(product_id: current_store.products.select(:id))
          end
        end
      end
    end
  end
end
