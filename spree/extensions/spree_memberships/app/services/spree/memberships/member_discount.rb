module Spree
  module Memberships
    # What the member price took off one order — money the platform owes the
    # seller, not the seller.
    #
    # A line counts only when the tier's own price list is what priced it. The
    # pricing walk stamps the list it used onto the line, and that stamp is the
    # one thing telling a member price apart from a concession the seller made:
    # a promotion, a store-wide agreement and a member price all leave the
    # customer paying less.
    #
    # Each reduction is measured against the variant's own price row, which is
    # what a list derives from — the figure the customer did not pay, rather
    # than a percentage read back from a list that may have moved since.
    class MemberDiscount
      prepend Spree::ServiceModule::Base

      # @param order [Spree::Order]
      # @return [Spree::ServiceModule::Result] value is a Hash of line item id
      #   => the gross amount that line was reduced by
      def call(order:)
        tier = Spree::MembershipTierSetting.for_store(order.store).for_customer(order.customer)
        return success({}) if tier.nil?

        list_ids = price_list_ids(tier)
        return success({}) if list_ids.empty?

        success(discounts_for(order, list_ids))
      end

      private

      # Empty when the tier grants no member price, or when its catalogue is out
      # of effect: a catalogue that is not applying prices nobody.
      #
      # @return [Array<Integer>]
      def price_list_ids(tier)
        catalog = tier.catalog
        return [] if catalog.nil? || !catalog.active?

        [catalog.price_list&.id].compact
      end

      # @return [Hash{Integer => BigDecimal}]
      def discounts_for(order, list_ids)
        lines = order.line_items.select { |line_item| list_ids.include?(line_item.price_list_id) }
        return {} if lines.empty?

        bases = base_amounts(lines.map(&:variant_id), order.currency)

        lines.each_with_object({}) do |line_item, discounts|
          base = bases[line_item.variant_id]
          next if base.nil?

          reduction = (base - line_item.price.to_d) * line_item.quantity
          discounts[line_item.id] = reduction if reduction.positive?
        end
      end

      # The shelf price each variant carries in this order's currency.
      #
      # @return [Hash{Integer => BigDecimal}]
      def base_amounts(variant_ids, currency)
        Spree::Price.base_prices.
          with_currency(currency).
          where(variant_id: variant_ids).
          where.not(amount: nil).
          pluck(:variant_id, :amount).to_h { |variant_id, amount| [variant_id, amount.to_d] }
      end
    end
  end
end
