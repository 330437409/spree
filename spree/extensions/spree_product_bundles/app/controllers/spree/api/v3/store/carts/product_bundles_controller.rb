module Spree
  module Api
    module V3
      module Store
        module Carts
          # The sets this cart holds, gathered back into the cards a storefront
          # renders: the cart itself carries the components as ordinary lines,
          # and this is the reading that puts them together again.
          #
          # The gem's own read rather than a field on the cart payload, because
          # core stays free of a vocabulary only this fork has
          # (docs/plans/fork-decisions.md, 2026-09-20).
          class ProductBundlesController < Store::BaseController
            include Spree::Api::V3::CartResolvable

            before_action :find_cart!

            # GET /api/v3/store/carts/:cart_id/product_bundles
            def index
              render json: { data: groups.map { |bundle, line_items| serialize_group(bundle, line_items) } }
            end

            private

            # Each bundle the cart holds lines for, with those lines: the group
            # rows are what say which of the cart's lines form a set.
            # @return [Hash{Spree::ProductBundle => Array<Spree::LineItem>}]
            def groups
              rows = Spree::BundleLineItem.where(owner: @cart).includes(:bundle, :line_item)

              rows.group_by(&:bundle).transform_values { |group| group.map(&:line_item) }
            end

            def serialize_group(bundle, line_items)
              Spree::Api::V3::CartProductBundleSerializer.new(
                Spree::ProductBundles::CartGroup.new(bundle: bundle, line_items: line_items),
                params: serializer_params
              ).to_h
            end
          end
        end
      end
    end
  end
end
