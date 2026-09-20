module Spree
  module Api
    module V3
      module Admin
        # The operator's own resource: creating a set from components, editing
        # what is in it, and taking it off sale.
        #
        # The whole CRUD comes from the Admin API's base class — full CRUD, key
        # scopes and CanCanCan, the same rendering and the same error shape as
        # every other admin resource — so this controller declares only what it
        # is about.
        class ProductBundlesController < ResourceController
          scoped_resource :product_bundles

          protected

          def model_class
            Spree::ProductBundle
          end

          def serializer_class
            Spree::Api::V3::Admin::ProductBundleSerializer
          end

          # Flat params, and the composition is the whole set: a component the
          # payload leaves out is one the operator removed, which the model's
          # own writer applies.
          def resource_permitted_attributes
            [
              :title, :slug, :status, :position, :seller_id,
              :preferred_discount_kind, :preferred_discount_value,
              { components: [:variant_id, :quantity] }
            ]
          end

          # The panel renders the composition and the figures it computes, so a
          # listing that did not load the components would pay per row.
          def scope_includes
            [components: [:variant]]
          end

          def scope
            super.ordered
          end
        end
      end
    end
  end
end
