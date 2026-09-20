module Spree
  module Purchase
    # Digitality predicates over line items, shared by Spree::Cart and
    # Spree::Order (fulfillment-side digital delivery stays order-only in
    # Spree::Order::Digital).
    module DigitalItems
      # @return [Boolean] true when every line item is digital
      def digital?
        return false if priced_line_items.empty?

        priced_line_items.includes(variant: :product).all?(&:digital?)
      end

      # @return [Boolean] true when any line item is digital
      def some_digital?
        return false if priced_line_items.empty?

        priced_line_items.includes(variant: :product).any?(&:digital?)
      end

      # @return [Boolean] true when any line item has digital assets
      def with_digital_assets?
        return false if priced_line_items.empty?

        priced_line_items.includes(:variant).any?(&:with_digital_assets?)
      end

      # @return [ActiveRecord::Relation<Spree::LineItem>]
      def digital_line_items
        priced_line_items.joins(:variant).with_digital_assets.distinct
      end

      # One query rather than one per line item — this is read for every
      # digital order's email. `reorder(nil)` drops the line-item default order:
      # PostgreSQL rejects SELECT DISTINCT ordered by a column that is not in
      # the select list, and ordering a subquery buys nothing anyway.
      #
      # @return [ActiveRecord::Relation<Spree::DigitalLink>]
      def digital_links
        Spree::DigitalLink.where(line_item_id: digital_line_items.reorder(nil).select(:id))
      end

      # Whether the customer must choose a delivery option in checkout —
      # shipping and both pickup kinds are chosen; digital fulfillments are
      # created by their provider without a selection. Delivery itself
      # happens for all of them.
      #
      # @return [Boolean]
      def delivery_step_required?
        priced_line_items.any? && !digital?
      end
    end
  end
end
