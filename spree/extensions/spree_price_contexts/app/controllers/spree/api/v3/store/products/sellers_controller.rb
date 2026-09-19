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
            # and from the store's own products, so an id belonging to another
            # tenant is a 404 rather than a foreign shop's sellers.
            def set_parent
              id = params[:product_id].to_s

              @product = if id.start_with?('prod_')
                           product_scope.find_by_prefix_id!(id)
                         else
                           find_with_fallback_default_locale { product_scope.i18n.find_by!(slug: id) }
                         end
            end

            def scope
              Spree::PriceContexts::ProductSellers.call(product: @product)
            end

            # The same narrowing the product read applies — published, and inside
            # the catalogue this request resolves — so a product the storefront
            # answers 404 for does not answer here with the shops holding it.
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

            # The collection is a plain `spree_sellers` relation with no joins,
            # so it cannot repeat a row and the DISTINCT the base adds buys
            # nothing — while costing something on PostgreSQL, which refuses
            # `SELECT DISTINCT ... ORDER BY id` on a translated model.
            def collection_distinct?
              false
            end

            # The inherited key is built from the returned sellers and the
            # request's own params, so two lists that look alike at the same
            # second would share a validator — and a validator has to identify
            # this list rather than any list like it. The store is in it as well
            # as the path, because two stores served from one host answer the
            # same path for two different shops.
            def collection_cache_key(collection)
              "#{current_store.id}/#{request.path}/#{super}"
            end
          end
        end
      end
    end
  end
end
