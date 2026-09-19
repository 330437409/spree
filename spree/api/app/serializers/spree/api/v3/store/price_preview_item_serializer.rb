module Spree
  module Api
    module V3
      module Store
        # One line of a preview: the price that would be charged, the price to
        # strike through when a list set it, and what the shelf says.
        class PricePreviewItemSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize variant_id: [:string, nullable: true],
                   product_id: [:string, nullable: true],
                   quantity: :number,
                   unit_amount: [:number, nullable: true],
                   compare_at_amount: [:number, nullable: true],
                   total: [:number, nullable: true],
                   price_list_id: [:string, nullable: true],
                   price_source: [:string, nullable: true],
                   in_stock: :boolean, backorderable: :boolean, purchasable: :boolean,
                   available_quantity: :number

          attribute :variant_id do |row|
            row.variant&.prefixed_id
          end

          attribute :product_id do |row|
            row.variant&.product&.prefixed_id
          end

          attribute :quantity do |row|
            row.quantity
          end

          attribute :unit_amount do |row|
            next nil if params[:hide_prices]

            row.unit_amount&.to_f
          end

          attribute :compare_at_amount do |row|
            next nil if params[:hide_prices]

            row.compare_at_amount&.to_f
          end

          attribute :total do |row|
            next nil if params[:hide_prices]

            row.total&.to_f
          end

          attribute :price_list_id do |row|
            next nil if params[:hide_prices]

            row.price_list_id
          end

          attribute :price_source do |row|
            next nil if params[:hide_prices]

            row.price_source
          end

          attributes :in_stock, :backorderable, :purchasable, :available_quantity
        end
      end
    end
  end
end
