module Spree
  module Api
    module V3
      module Store
        # A bundle as a cart holds it: the set's own words and figures, with the
        # ordinary lines it was added as.
        #
        # The lines are serialized by the Store API's own line item serializer,
        # because that is exactly what they are to a client — a group is a
        # reading of the cart, not a second kind of line.
        class CartProductBundleSerializer < BaseSerializer
          typelize title: :string, slug: :string, quantity: :number,
                   goods_price: :number, price: :number, saving: :number, available: :number,
                   bundle_id: [:string, nullable: true]

          attributes :title, :slug

          attribute :bundle_id do |group|
            group.bundle&.prefixed_id
          end

          # How many whole sets the group holds, which is the number its stepper
          # moves.
          attribute :quantity do |group|
            group.quantity
          end

          attribute :goods_price do |group|
            group.goods_price.to_f
          end

          attribute :price do |group|
            group.price.to_f
          end

          attribute :saving do |group|
            group.saving.to_f
          end

          attribute :available do |group|
            group.available
          end

          many :line_items, resource: proc { Spree.api.line_item_serializer }

          private

          def currency
            params[:currency] || Spree::Current.currency
          end
        end
      end
    end
  end
end
