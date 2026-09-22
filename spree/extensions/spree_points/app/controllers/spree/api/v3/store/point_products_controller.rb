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

          # Stock, the price and the shelf move when an operator edits them, and
          # nothing here is worth caching across that.
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
            Spree::Api::V3::Store::PointProductSerializer
          end

          def scope
            products = super.ordered

            products = products.for_category(params[:category]) if params[:category].present?
            products = products.featured if ActiveModel::Type::Boolean.new.cast(params[:featured])
            products = products.for_seller(Spree::Current.seller) if params[:audience] == 'member'

            products
          end

          # The labels above the list, beside the page of goods rather than in
          # a read of their own: the client's `getIntegralGoodsCategory` is the
          # same list it already has to page through.
          def collection_meta(collection)
            super.merge(categories: category_labels)
          end

          private

          def category_labels
            scope.unscope(:order).where.not(category: nil).distinct.pluck(:category).sort
          end
        end
      end
    end
  end
end
