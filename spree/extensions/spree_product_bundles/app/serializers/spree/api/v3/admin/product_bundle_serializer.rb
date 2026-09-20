module Spree
  module Api
    module V3
      module Admin
        # A bundle as a merchant's own panel reads it: what the storefront sees,
        # plus the operator's own fields — the status they move, the position
        # they order by, and the timestamps.
        class ProductBundleSerializer < Spree::Api::V3::Store::ProductBundleSerializer
          typelize status: :string, position: :number,
                   created_at: :string, updated_at: :string, deleted_at: [:string, nullable: true]

          attributes :status, :position, :created_at, :updated_at, :deleted_at
        end
      end
    end
  end
end
