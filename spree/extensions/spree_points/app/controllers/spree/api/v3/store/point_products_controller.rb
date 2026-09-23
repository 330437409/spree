module Spree
  module Api
    module V3
      module Store
        # The points shop.
        #
        # One collection answers the client's page, its category tabs, the
        # featured shelf and the member shelf between them, because those
        # differ in filter rather than in shape; the category labels the tabs
        # read come from the collection's own meta.
        class PointProductsController < ResourceController
          include Spree::Api::V3::HttpCaching

          # The member shelf is answered for a site, so a request naming one
          # without a resolved seller is refused rather than served the
          # store-wide shelf: a shelf silently missing a seller's goods reads
          # as a shelf with nothing in it.
          before_action :require_seller_for_member_shelf, if: :member_shelf?

          # Stock and the price move when an operator edits them, and what the
          # store's own database holds is what answers the request; nothing
          # here is worth caching across that. The concern is still included,
          # because its Vary headers and its no-store for a signed-in customer
          # are what keep a cache from mixing sites and channels.
          def cache_collection(_collection, **_options)
            true
          end

          def cache_resource(_resource, **_options)
            true
          end

          protected

          def model_class
            Spree::PointProduct
          end

          def serializer_class
            Spree::Api::V3::PointProductSerializer
          end

          def scope
            products = audience(super)

            # `category` and `featured` narrow a page, not a shelf: a detail
            # read carrying the tab it came from still has to find its good.
            return products unless action_name == 'index'

            products = products.for_category(params[:category]) if params[:category].present?
            params[:featured].present? ? featured_shelf(products) : products
          end

          # The operator's order: `position` is theirs to set, and the id
          # breaks a tie between two goods added before either is moved.
          def apply_collection_sort(collection)
            collection.reorder(:position, :id)
          end

          # The labels above the list, beside the page of goods rather than in
          # a read of their own: the client's `getIntegralGoodsCategory` is the
          # same list it already has to page through.
          #
          # They are read off the shelf, not off the page: a facet narrowed by
          # the filter it exists to describe would leave one tab on the strip.
          def collection_meta(collection)
            super.merge(categories: category_labels)
          end

          private

          def require_seller_for_member_shelf
            return if Spree::Current.seller

            render_error(
              code: ErrorHandler::ERROR_CODES[:parameter_invalid],
              message: Spree.t('api.errors.member_shelf_needs_a_seller',
                               default: 'The member shelf is answered for a site this request did not name'),
              status: :unprocessable_content
            )
          end

          def member_shelf?
            params[:audience].to_s.downcase == 'member'
          end

          # `true` is the featured strip and `false` its complement, so a
          # client asking for the plain goods is answered those alone.
          def featured_shelf(products)
            ActiveModel::Type::Boolean.new.cast(params[:featured]) ? products.featured : products.where(featured: false)
          end

          # A seller's shelf is that seller's goods beside the store's, which
          # is what a request that resolved a seller shops from.
          def audience(products)
            return products unless member_shelf?

            products.available_to_seller(Spree::Current.seller)
          end

          def category_labels
            audience(model_class.for_store(current_store)).where.not(category: nil).distinct.pluck(:category).sort
          end
        end
      end
    end
  end
end
