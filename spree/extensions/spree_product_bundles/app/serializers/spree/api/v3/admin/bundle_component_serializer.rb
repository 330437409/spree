module Spree
  module Api
    module V3
      module Admin
        # The storefront's component, plus the record's own timestamps: a merchant
        # panel sorts and filters on them, and the admin branch carries them
        # everywhere else.
        #
        # It is also what the admin bundle nests, because the admin writer names a
        # nested serializer by its own class — `Admin::ProductBundleSerializer`
        # points at this one, so the generated admin type resolves to a name the
        # package has.
        class BundleComponentSerializer < Spree::Api::V3::BundleComponentSerializer
          typelize created_at: :string, updated_at: :string

          attributes :created_at, :updated_at
        end
      end
    end
  end
end
