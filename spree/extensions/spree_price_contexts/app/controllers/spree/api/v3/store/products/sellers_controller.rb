module Spree
  module Api
    module V3
      module Store
        module Products
          # Which sellers hold an offer for this product.
          #
          # A list rather than a verdict: two sellers may hold variants of one
          # product, and which of them serves the customer is a question about
          # the customer's location — the routing read answers that — while this
          # one answers what exists in the catalogue.
          class SellersController < ResourceController
            include Spree::Api::V3::HttpCaching

            protected

            def model_class
              Spree::Seller
            end

            def serializer_class
              Spree.api.seller_serializer
            end

            # Resolved the way the products read resolves one — a prefixed ID, or
            # a slug in the current locale with the store's default behind it —
            # and always from the store's own products, so an id belonging to
            # another tenant is a 404 rather than a foreign shop's sellers.
            def set_parent
              id = params[:product_id].to_s

              @product = if id.start_with?('prod_')
                           current_store.products.find_by_prefix_id!(id)
                         else
                           find_with_fallback_default_locale { current_store.products.i18n.find_by!(slug: id) }
                         end
            end

            def scope
              Spree::PriceContexts::ProductSellers.call(product: @product)
            end
          end
        end
      end
    end
  end
end
