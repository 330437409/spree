module Spree
  module Api
    module V3
      module Admin
        # A bundle as a merchant's own panel reads it: what the storefront sees,
        # plus the operator's own fields — the status they move, the position
        # they order by, and the timestamps.
        class ProductBundleSerializer < Spree::Api::V3::ProductBundleSerializer
          typelize status: :string, position: :number,
                   currency: :string,
                   saving_kind: :string, saving_value: :number,
                   created_at: :string, updated_at: :string, deleted_at: [:string, nullable: true]

          attributes :status, :position, :created_at, :updated_at, :deleted_at

          # Nested through the admin twin, not the storefront's serializer it
          # inherits: the admin writer names a nested type by its own class, so a
          # reference to the store one would come out as a name no package has.
          many :components, resource: proc { Spree::Api::V3::Admin::BundleComponentSerializer }

          # The rule itself, which is what a merchant edits: the panel shows the
          # three computed figures beside it, and it needs the rule to fill the
          # form back in.
          attribute :saving_kind do |bundle|
            bundle.preferred_discount_kind
          end

          attribute :saving_value do |bundle|
            bundle.preferred_discount_value.to_f
          end

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
