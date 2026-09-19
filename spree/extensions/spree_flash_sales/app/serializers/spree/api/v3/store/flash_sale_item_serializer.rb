module Spree
  module Api
    module V3
      module Store
        # Which offer an activity sells, and both prices: the activity's own,
        # and the goods' list price beside it for the client to strike through.
        class FlashSaleItemSerializer < BaseSerializer
          typelize sale_price: :number, price: [:number, nullable: true]

          attribute :variant_id do |item|
            item.variant&.prefixed_id
          end

          attribute :product_id do |item|
            item.variant&.product&.prefixed_id
          end

          attribute :price do |item|
            price_in(item.variant)&.amount&.to_f
          end

          attribute :sale_price do |item|
            item.sale_amount&.to_f
          end

          attribute :remaining do |item|
            item.flash_sale.progress(item: item).fetch(:remaining)
          end
        end
      end
    end
  end
end
