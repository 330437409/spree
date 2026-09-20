module Spree
  class PricePreview
    # One requested line, priced and answered.
    #
    # The amounts are the resolved ones; `price` keeps the record they came from
    # so a caller can say which list priced the line and which source answered —
    # the provenance a report has to be able to read.
    class Row
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :variant
      attribute :quantity, :integer
      attribute :price
      attribute :unit_amount
      attribute :compare_at_amount
      attribute :total
      attribute :in_stock, :boolean
      attribute :backorderable, :boolean
      attribute :purchasable, :boolean
      attribute :available_quantity, :integer
      attribute :price_list_id
      # Which registered source priced this line, when one did rather than the
      # catalogue, and the verdicts it brought with it.
      attribute :source
      attribute :flags, default: -> { {} }

      def price_source
        price&.price_source
      end
    end
  end
end
