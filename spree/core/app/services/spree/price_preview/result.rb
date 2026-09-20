module Spree
  class PricePreview
    # The answer: one row per requested line, and what they come to together.
    class Result
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :currency
      attribute :rows, default: -> { [] }

      # nil rather than a number when a line cannot be priced: a basket whose
      # total silently leaves that line out is worse than one that says it does
      # not know.
      def total
        return nil if rows.any? { |row| row.unit_amount.blank? }

        rows.sum { |row| row.total.to_d }
      end

      def quantity
        rows.sum(&:quantity)
      end

      # Whether anything asked for can be bought at all — the one verdict a page
      # needs before it renders a buy button.
      def purchasable?
        rows.any? && rows.all? { |row| row.purchasable && row.unit_amount.present? }
      end
    end
  end
end
