module Spree
  module Api
    module V3
      module Store
        class WishlistItemsController < ResourceController
          prepend_before_action :require_authentication!

          # The tabs above a wishlist page: the categories the collected goods
          # fall into. Its own read rather than a field the client groups by —
          # drawing the tabs would otherwise mean fetching every collected good
          # to find out what they are
          # (docs/plans/6.1-store-api-miniprogram-gaps.md).
          def categories
            render json: {
              data: collected_categories.map do |category|
                Spree.api.category_serializer.new(category, params: serializer_params).to_h
              end
            }
          end

          protected

          def set_parent
            @parent = storefront_access_policy.
                      scope(Spree::Wishlist.for_store(current_store)).
                      find_by_prefix_id!(params[:wishlist_id])

            # The list and its tabs are reads; adding, changing or removing a
            # collected good is a write.
            if read_actions.include?(action_name)
              authorize_storefront_read!(@parent)
            else
              authorize_storefront_write!(@parent)
            end
          end

          def parent_association
            :wishlist_items
          end

          def model_class
            Spree::WishlistItem
          end

          def serializer_class
            Spree.api.wishlist_item_serializer
          end

          def resource_permitted_attributes
            [:variant_id, :quantity]
          end

          # `categories` is a read too, so the access policy does not ask it to
          # prove the caller may write.
          def read_actions
            super + %w[categories]
          end

          def collection_includes
            super + [variant: :product]
          end

          # A wishlist page opens on what was collected last, and narrows to one
          # category when the tabs ask it to.
          def scope
            relation = super.recent_first
            return relation if category.nil?

            relation.joins(variant: :product).
              where(Spree::Product.table_name => { id: category.products.reorder(nil).select(:id) })
          end

          private

          # Resolved through the store's own list, so a category of another
          # store is not one at all — and a tab the merchandise department has
          # since deleted is a 404 rather than a silently empty page.
          #
          # @return [Spree::Category, nil]
          def category
            return @category if defined?(@category)

            id = params[:category_id]
            @category = id.present? ? current_store.categories.find_by_prefix_id!(id) : nil
          end

          # The categories the wishlist's goods are in, in the order the
          # catalogue presents categories in.
          #
          # @return [ActiveRecord::Relation]
          def collected_categories
            category_ids = Spree::ProductCategory.
                           where(product_id: @parent.products.select(:id)).
                           select(:category_id)

            current_store.categories.where(id: category_ids).manual
          end
        end
      end
    end
  end
end
