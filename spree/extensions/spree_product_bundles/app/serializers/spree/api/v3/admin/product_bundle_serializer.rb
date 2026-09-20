module Spree
  module Api
    module V3
      module Admin
        # A bundle as a merchant's own panel reads it: what the storefront sees,
        # plus the operator's own fields — the status they move, the position
        # they order by, and the timestamps.
        class ProductBundleSerializer < Spree::Api::V3::Store::ProductBundleSerializer
          typelize status: :string, position: :number,
                   currency: :string,
                   created_at: :string, updated_at: :string, deleted_at: [:string, nullable: true]

          attributes :status, :position, :created_at, :updated_at, :deleted_at

          # The currency every figure in this payload is in, so a panel formats
          # what it was given rather than guessing the store's own.
          attribute :currency do |bundle|
            bundle.store&.default_currency || Spree::Current.currency
          end
        end
      end
    end
  end
end
