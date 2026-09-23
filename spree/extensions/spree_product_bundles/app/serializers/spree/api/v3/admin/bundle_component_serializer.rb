module Spree
  module Api
    module V3
      module Admin
        # The storefront's component, plus the operator's own timestamps.
        #
        # It exists for the admin bundle's own nesting: the admin writer names a
        # nested serializer by its own class, so `Admin::ProductBundleSerializer`
        # nests this one and the generated admin type resolves to it.
        class BundleComponentSerializer < Spree::Api::V3::BundleComponentSerializer
          typelize created_at: :string, updated_at: :string

          attributes :created_at, :updated_at
        end
      end
    end
  end
end
