module Spree
  module Api
    module V3
      module Store
        module Carts
          # What else the shopper might want, from what is already in their
          # basket.
          #
          # Answered from the same catalogue every other product read answers
          # from, so a recommendation is never a way to see something the
          # catalogue would not show, and through the store's search provider,
          # so a store with an index and a store without one are answered the
          # same way (docs/plans/6.1-store-api-miniprogram-gaps.md).
          class RecommendationsController < Store::BaseController
            include Spree::Api::V3::CartResolvable
            include Spree::Api::V3::Store::ProductCatalogue

            before_action :find_cart!

            # GET /api/v3/store/carts/:cart_id/recommendations
            def index
              result = Spree.recommendations_for_cart_service.call(
                cart: @cart,
                scope: product_catalogue,
                limit: limit_param
              )

              return render_result_error(result) if result.failure?

              render json: { data: result.value.map { |product| serialize_product(product) } }
            end

            protected

            def model_class
              Spree::Product
            end

            private

            # The shelf is small by nature: a caller asking for a page of
            # recommendations gets a shelf.
            def limit_param
              requested = params[:limit].to_i
              requested = 12 unless requested.positive?

              [requested, 24].min
            end

            def serialize_product(product)
              Spree.api.product_serializer.new(product, params: serializer_params).to_h
            end
          end
        end
      end
    end
  end
end
