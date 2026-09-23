module Spree
  module Api
    module V3
      # One component of a bundle, as a storefront renders it: what the goods
      # are, how many the set holds, what they cost on their own, and whether
      # the shelf has them.
      #
      # Every figure is the variant's own answer rather than the bundle's —
      # a component's price and stock are the offer's — which is why a
      # storefront dims a sold-out component instead of hiding the bundle.
      class BundleComponentSerializer < BaseSerializer
        typelize name: [:string, nullable: true], quantity: :number,
                 price: [:number, nullable: true], goods_amount: [:number, nullable: true],
                 available: :number, in_stock: :boolean,
                 image_url: [:string, nullable: true]

        attribute :variant_id do |component|
          component.variant&.prefixed_id
        end

        attribute :product_id do |component|
          component.variant&.product&.prefixed_id
        end

        attribute :name do |component|
          component.variant&.product&.name || component.variant&.name
        end

        attribute :quantity do |component|
          component.quantity
        end

        # What one of them costs on its own — the 单买价 a card prints beside
        # the set's price.
        attribute :price do |component|
          component.variant&.amount_in(currency)&.to_f
        end

        attribute :goods_amount do |component|
          component.goods_amount(currency).to_f
        end

        attribute :available do |component|
          component.available_units.to_i
        end

        attribute :in_stock do |component|
          component.variant&.in_stock? || false
        end

        attribute :image_url do |component|
          image_url_for(component.variant&.product&.primary_media)
        end

        private

        def currency
          params[:currency] || Spree::Current.currency
        end
      end
    end
  end
end
