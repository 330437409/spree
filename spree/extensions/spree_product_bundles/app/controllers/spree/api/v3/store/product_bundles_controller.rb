module Spree
  module Api
    module V3
      module Store
        # The bundles a storefront shows: one collection and one member, which
        # between them answer the client's four calls — the combos a goods
        # belongs to, the menu's combo zone, the featured teaser and the buy
        # popup — because those differ in filter rather than in shape.
        class ProductBundlesController < ResourceController
          include Spree::Api::V3::HttpCaching

          protected

          # What a bundle costs and how many the shelf can fill are both read at
          # the moment of the answer, and neither moves the bundle's own
          # `updated_at` when a component sells: a shared cache would serve a
          # price and a count that contradict the cart it then writes. The reads
          # are cheap; they are simply not cached. (The concern is still
          # included, because its Vary headers are what keeps a cache from
          # mixing channels.)
          def cache_collection(_collection, **_options)
            true
          end

          def cache_resource(_resource, **_options)
            true
          end

          def model_class
            Spree::ProductBundle
          end

          def serializer_class
            Spree::Api::V3::ProductBundleSerializer
          end

          # Only what a shopper can buy today: an archived bundle is not
          # offered, and neither is one whose seller is not selling.
          def scope
            super.available
          end

          # A bundle's price and availability are computed from the components,
          # so a listing that does not carry them pays for each row.
          def collection_includes
            [components: [:variant]]
          end

          def scope_includes
            collection_includes
          end

          # The bundle's prefixed id or its slug, whichever the client holds.
          def find_resource
            id = params[:id]
            return scope.find_by!(slug: id) unless id.to_s.start_with?('bundle_')

            scope.find_by_prefix_id!(id)
          end
        end
      end
    end
  end
end
