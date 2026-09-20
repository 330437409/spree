module Spree
  module Api
    module V3
      module Store
        module Carts
          # How much is in the cart, without reading the cart.
          #
          # A storefront asks this on every page it shows a badge on — the
          # product pages, the menu — where the cart payload's lines, variants,
          # media and prices are all work nobody asked for. It is a read of the
          # cart, not of a thing of its own, so the serializer answers from the
          # cart's own columns
          # (docs/plans/6.1-store-api-miniprogram-gaps.md).
          class CountController < Store::BaseController
            include Spree::Api::V3::CartResolvable

            before_action :find_cart

            # GET /api/v3/store/carts/:cart_id/count
            def show
              render json: serializer_class.new(@cart, params: serializer_params).to_h
            end

            private

            def serializer_class
              Spree::Api::V3::CartCountSerializer
            end
          end
        end
      end
    end
  end
end
