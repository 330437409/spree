module Spree
  module Api
    module V3
      module Store
        class ProductsController < ResourceController
          include Spree::Api::V3::HttpCaching
          include Spree::Api::V3::Store::SearchProviderSupport

          # The most ids one batch load may ask for. The response is the page,
          # and a page holds this many, so a longer list is a request to split
          # rather than an answer quietly cut short.
          MAX_BATCH_IDS = 100

          # A batch load: the products the caller already holds ids for. The
          # search provider is deliberately not consulted — it answers from an
          # index, and a product published a moment ago may not be in it yet,
          # while this question is about the catalogue itself.
          def index
            return if render_over_long_batch

            super
          end

          protected

          # @return [Boolean] true when the request was refused
          def render_over_long_batch
            return false if requested_ids.size <= MAX_BATCH_IDS

            render_error(
              code: ErrorHandler::ERROR_CODES[:validation_error],
              message: "ids must be at most #{MAX_BATCH_IDS}",
              status: :unprocessable_content
            )
            true
          end

          # The ids the caller asked for, as they sent them — the cap is on what
          # was asked for rather than on what resolved.
          # @return [Array<String>]
          def requested_ids
            @requested_ids ||= begin
              raw = params[:ids]
              case raw
              when nil then []
              when Array then raw.map(&:to_s)
              when String then raw.split(',')
              else
                []
              end
            end
          end

          # The requested ids as primary keys, in the order asked for and
          # without duplicates. An id that names nothing — another store's
          # product, a deleted one, a mistyped prefix — is simply absent from
          # the answer: a batch is a set the caller already holds, and some of
          # it may be gone.
          # @return [Array<String>]
          def batch_ids
            @batch_ids ||= requested_ids.filter_map { |id| model_class.decode_own_prefixed_id(id) }.uniq
          end

          def collection
            return @collection if @collection.present?
            return @collection = collection_by_ids if batch_ids.any?

            super
          end

          # A batch answers the whole batch unless the caller pages it: the
          # limit is what they asked for, which is never more than a page.
          def collection_by_ids
            relation = scope.where(id: batch_ids)
            @pagy, products = pagy(relation, limit: batch_limit, page: page)
            products
          end

          def batch_limit
            params[:limit].present? ? limit : batch_ids.size
          end

          # A batch is its own collection, so its identity is the ids it names
          # — the shared key would let two different batches share an ETag.
          def collection_cache_key(collection)
            return super if batch_ids.empty?

            "#{super}/#{batch_ids.sort.join(',')}"
          end


          def model_class
            Spree::Product
          end

          def serializer_class
            Spree.api.product_serializer
          end

          # Find product by slug or prefixed ID with i18n scope for SEO-friendly URLs
          # Falls back to default locale if product is not found in the current locale
          # @return [Spree::Product]
          def find_resource
            id = params[:id]
            if id.to_s.start_with?('prod_')
              scope.find_by_prefix_id!(id)
            else
              find_with_fallback_default_locale { scope.i18n.find_by!(slug: id) }
            end
          end

          def scope
            base = super.available(Time.current, Spree::Current.currency, include_preorderable: true)

            # Catalog narrowing for the buyer: their company's effective
            # catalogs, their group's, or the channel default — union of
            # assortments, resolved in one place
            # (docs/plans/6.0-b2b-companies-and-catalogs.md).
            Spree.products_for_context_service.call(
              store: current_store,
              channel: current_channel,
              customer: current_user,
              base: base
            ).value
          end

          # these scopes are not automatically picked by ar_lazy_preload gem and we need to explicitly include them
          def scope_includes
            [
              # `seller` is declared on both sides rather than left to lazy
              # preloading: the buy box asks every variant who is selling it,
              # and a variant with no seller of its own asks its product — so a
              # listing would otherwise depend on ambient behaviour to avoid an
              # N+1 on whichever of the two answers.
              :seller,
              {
                product_publications: [],
                primary_media: [attachment_attachment: :blob, poster_attachment: :blob],
                default_variant: [:prices, stock_levels: [:stock_location, :active_stock_reservations]],
                variants: [:prices, :seller, stock_levels: [:stock_location, :active_stock_reservations]]
              }
            ]
          end

          # Override collection to use search provider.
          # The provider handles search, filtering, sorting, pagination, and returns a Pagy object.
          def collection
            return @collection if @collection.present?

            result = search_provider.search_and_filter(
              scope: scope.includes(collection_includes).preload_associations_lazily,
              query: search_query,
              filters: search_filters,
              sort: sort_param,
              page: page,
              limit: limit
            )

            @pagy = result.pagy
            @collection = result.products
          end
        end
      end
    end
  end
end
