module Spree
  module Api
    module V3
      module Store
        class ProductsController < ResourceController
          include Spree::Api::V3::HttpCaching
          include Spree::Api::V3::Store::SearchProviderSupport
          include Spree::Api::V3::Store::ProductCatalogue

          # The most ids one batch load may ask for. The response is the page,
          # and a page holds this many, so a longer list is a request to split
          # rather than an answer quietly cut short.
          MAX_BATCH_IDS = 100

          # A batch load: the products the caller already holds ids for. The
          # search provider is deliberately not consulted — it answers from an
          # index, and a product published a moment ago may not be in it yet,
          # while this question is about the catalogue itself.
          def index
            return if render_unusable_batch

            super
          end

          protected

          # A batch answers the set it was given, so two requests are refused
          # rather than half-answered: one that asks for more ids than a page
          # holds, and one that also sends a filter or an ordering — dropping
          # those silently would answer a page the caller did not ask for.
          # @return [Boolean] true when the request was refused
          def render_unusable_batch
            return false if requested_ids.empty?
            return render_batch_refusal('ids cannot be combined with q or sort') if params[:q].present? || params[:sort].present?
            return render_batch_refusal("ids must be at most #{MAX_BATCH_IDS}") if requested_ids.size > MAX_BATCH_IDS

            false
          end

          def render_batch_refusal(message)
            render_error(
              code: ErrorHandler::ERROR_CODES[:validation_error],
              message: message,
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

          # The batch branch is taken whenever the caller asked for one, even
          # when nothing they sent resolves: answering the whole catalogue
          # instead of an empty set is the one answer a batch must not give.
          def batch_requested?
            requested_ids.any?
          end

          # A batch answers the whole batch unless the caller pages it: the
          # limit is what they asked for, which is never more than a page.
          def collection_by_ids
            relation = scope.where(id: batch_ids)
            @pagy, products = pagy(relation, limit: batch_limit, page: page)
            products
          end

          # A batch whose ids resolved to nothing still needs a limit — a page
          # of zero rows, asked for at the ordinary size.
          def batch_limit
            return limit if params[:limit].present? || batch_ids.empty?

            batch_ids.size
          end

          # A batch is its own collection, so its identity is the ids it names
          # — the shared key would let two different batches share an ETag.
          def collection_cache_key(collection)
            return super unless batch_requested?

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

          # Catalog narrowing for the buyer: their company's effective
          # catalogs, their group's, or the channel default — union of
          # assortments, resolved in one place
          # (docs/plans/6.0-b2b-companies-and-catalogs.md).
          def scope
            product_catalogue(super)
          end

          # The listing loads the same associations as every other read of this
          # catalogue — see Spree::Api::V3::Store::ProductCatalogue.
          def scope_includes
            catalogue_includes
          end

          # Override collection to use search provider.
          # The provider handles search, filtering, sorting, pagination, and returns a Pagy object.
          #
          # A batch load is answered before the provider is consulted: it is not
          # a search but a set the caller already holds, and an id answered from
          # an index would be missing the products published since the last one.
          def collection
            return @collection if @collection.present?
            return @collection = collection_by_ids if batch_requested?

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
