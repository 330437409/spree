module Spree
  module Api
    module V3
      module Store
        module Customer
          # What this customer has already bought: one set of products, read two
          # ways — most recently bought, or bought most often. The two shelves
          # the mini program renders from it (买过 / 常买) differ only in the
          # ordering, so they are one read rather than two
          # (docs/plans/6.1-store-api-miniprogram-gaps.md).
          class PurchaseHistoryController < ResourceController
            include Spree::Api::V3::Store::ProductCatalogue

            prepend_before_action :require_authentication!

            # `recent` is what a customer means by "bought before"; `frequent`
            # is the shop's own suggestion of what to buy again.
            SORTS = %w[recent frequent].freeze

            def index
              return if render_unusable_sort

              super
            end

            protected

            def model_class
              Spree::Product
            end

            def serializer_class
              Spree.api.product_serializer
            end

            # The history is a subset of the catalogue this request may see —
            # a product the customer bought and the shop no longer offers, or
            # one their channel no longer carries, is not an answer to "buy it
            # again" (see Spree::Api::V3::Store::ProductCatalogue).
            def base_scope
              @base_scope ||= product_catalogue
            end

            def scope
              base_scope.purchased_by(current_user, order_by: sort_param)
            end

            # The ordering is an aggregate over this customer's own orders and
            # the rows are grouped by product, so the page is taken over product
            # ids and the products then loaded from them — counting a grouped
            # relation counts groups, and paging it would page them.
            def collection
              return @collection if @collection.present?

              ordered = scope
              @pagy = Pagy::Offset.new(count: ordered.count.size, page: page, limit: limit)
              ids = ordered.offset(@pagy.offset).limit(@pagy.limit).pluck(:id)
              by_id = base_scope.where(id: ids).index_by(&:id)

              @collection = ids.filter_map { |id| by_id[id] }
            end

            # The ordering, not a Ransack sort field. An unknown one is a
            # request to fix rather than a silent fall back to the default.
            def sort_param
              params[:sort].presence || 'recent'
            end

            def render_unusable_sort
              return false if SORTS.include?(sort_param)

              render_error(
                code: ErrorHandler::ERROR_CODES[:validation_error],
                message: "sort must be one of: #{SORTS.join(', ')}",
                status: :unprocessable_content
              )
              true
            end
          end
        end
      end
    end
  end
end
