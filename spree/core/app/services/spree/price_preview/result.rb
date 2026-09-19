module Spree
  class PricePreview
    # The answer: one row per requested line, and what they come to together.
    class Result
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :currency
      attribute :rows, default: -> { [] }

      def total
        rows.sum { |row| row.total.to_d }
      end

      def quantity
        rows.sum(&:quantity)
      end

      # Whether anything asked for can be bought at all — the one verdict a page
      # needs before it renders a buy button.
      def purchasable?
        rows.any? && rows.all?(&:purchasable)
      end
    end
  end
end
