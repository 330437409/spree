module Spree
  module Api
    module V3
      module Store
        # The storefront's flash-sale reads: the list, one activity, and the
        # activity a goods is on.
        #
        # An ended activity is absent rather than rendered in a third state —
        # the window is a filter here, not a field every client remembers to
        # check — and a seller who is not selling today takes their activities
        # with them.
        class FlashSalesController < ResourceController
          include Spree::Api::V3::HttpCaching

          # GET /api/v3/store/flash_sales/by_product/:product_id
          #
          # The same activity asked the way the buy popup asks it: by the goods.
          def by_product
            product = current_store.products.find_by_prefix_id!(params[:product_id])
            sale = scope.joins(items: :variant).
                   where(Spree::Variant.table_name => { product_id: product.id }).
                   order(:starts_at).first

            raise ActiveRecord::RecordNotFound if sale.nil?

            render json: serialize_resource(sale)
          end

          protected

          # `server_now`, the window's status and every pool figure are read at
          # the moment of the answer, and neither the activity's `updated_at`
          # nor a counter's moves when a claim does — so a shared cache holding
          # this body would serve a countdown anchored to a stale instant and a
          # 剩余 that contradicts the claim it then refuses. The reads are cheap;
          # they are simply not cached. (The concern is still included, because
          # its Vary headers are what keeps a cache from mixing channels.)
          def cache_collection(_collection, **_options)
            true
          end

          def cache_resource(_resource, **_options)
            true
          end

          def model_class
            Spree::FlashSale
          end

          def serializer_class
            Spree::Api::V3::Store::FlashSaleSerializer
          end

          def read_actions
            super + %w[by_product]
          end

          def collection_includes
            %i[items slots]
          end

          def scope
            sale = Spree::FlashSale.arel_table
            sellable = sale[:seller_id].eq(nil).or(sale[:seller_id].in(Spree::Seller.sellable.select(:id)))

            super.where(sale[:ends_at].gt(Time.current)).where(sellable)
          end
        end
      end
    end
  end
end
