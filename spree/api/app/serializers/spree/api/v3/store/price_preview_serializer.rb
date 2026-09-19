module Spree
  module Api
    module V3
      module Store
        # What the goods cost and whether they can be bought, in the context the
        # request carried.
        #
        # A computation rather than a record, so it carries no id: a plain Alba
        # resource is the right base here, and the item rows are their own
        # serializer rather than a hash built inside this one.
        class PricePreviewSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize currency: :string, total: :number, quantity: :number,
                   purchasable: :boolean, items: 'StorePricePreviewItem[]'

          attributes :currency

          attribute :total do |preview|
            preview.total.to_f
          end

          attribute :quantity do |preview|
            preview.quantity
          end

          attribute :purchasable do |preview|
            preview.purchasable?
          end

          attribute :items do |preview|
            preview.rows.map { |row| PricePreviewItemSerializer.new(row, params: params).to_h }
          end
        end
      end
    end
  end
end
