module Spree
  module ProductBundles
    # What the bundles in a cart save, written as the discount rows that carry
    # it: one row per component line, each naming the bundle it belongs to.
    #
    # A discount rather than a promotion action, because the promotion engine
    # reconciles its own rows destructively and the bundle's price competes with
    # nothing — the set costs what the set costs
    # (docs/plans/6.1-product-bundles.md).
    #
    # The saving is allocated over the group's own lines in proportion to what
    # each of them costs, with the rounding remainder on the last line by
    # position, so a return of one component reverses its share rather than
    # unwinding the whole saving. Recomputing is idempotent: every row is found
    # by its own code, and a group that has gone takes its rows with it.
    class ApplySaving
      prepend Spree::ServiceModule::Base

      # @param order [Spree::Cart, Spree::Order] the cart or order the lines
      #   belong to
      # @return [Spree::ServiceModule::Result] value is the rows written
      def call(order:)
        @order = order

        written = []
        groups.each do |bundle, line_items|
          written.concat(apply_to(bundle, line_items))
        end
        remove_stale_rows(written)

        @order.recalculate_totals! if @order.persisted?

        success(written)
      end

      private

      # Each bundle the order holds lines for, with those lines: the join rows
      # are what say which lines form a set.
      # @return [Hash{Spree::ProductBundle => Array<Spree::LineItem>}]
      def groups
        rows = Spree::BundleLineItem.where(owner: @order).includes(:bundle, :line_item)

        rows.group_by(&:bundle).transform_values { |group| group.map(&:line_item) }
      end

      # @return [Array<Spree::Discount>]
      def apply_to(bundle, line_items)
        saving = saving_for(bundle, line_items)
        return [] if saving.zero?

        shares = allocate(saving, line_items)

        line_items.filter_map do |line_item|
          share = shares[line_item.id]
          next if share.nil? || share.zero?

          write_row(bundle, line_item, share)
        end
      end

      # What the sets in this group save in total: the bundle's own saving times
      # how many whole sets the lines hold. A group the customer has cut down to
      # less than one set saves nothing, which is the same answer the client's
      # own availability threshold gives.
      # @return [BigDecimal]
      def saving_for(bundle, line_items)
        bundle.saving.to_d * sets_in(bundle, line_items)
      end

      # @return [Integer]
      def sets_in(bundle, line_items)
        quantities = bundle.components.map do |component|
          line = line_items.find { |item| item.variant_id == component.variant_id }
          line.nil? ? 0 : line.quantity / component.quantity
        end

        quantities.min || 0
      end

      # The saving over the lines, in proportion to what each costs. Any
      # rounding left over lands on the last line by position, so the shares
      # always add up to the saving itself.
      #
      # @return [Hash{Integer => BigDecimal}] keyed by line item id
      def allocate(saving, line_items)
        ordered = line_items.sort_by(&:id)
        bases = ordered.to_h { |line_item| [line_item.id, [line_item.amount.to_d, 0].max] }
        total = bases.values.sum
        return {} if total.zero?

        shares = {}
        allocated = BigDecimal(0)

        ordered.each_with_index do |line_item, index|
          share = if index == ordered.size - 1
                    saving - allocated
                  else
                    (saving * bases[line_item.id] / total).round(2)
                  end

          allocated += share
          shares[line_item.id] = [share, bases[line_item.id]].min
        end

        shares
      end

      # One row per line, found by its own code so a recomputation updates what
      # is there rather than stacking a second saving on the same set. The row
      # names the bundle in its metadata, which is also what makes a refund of a
      # component recomputable.
      def write_row(bundle, line_item, share)
        row = @order.discounts.find_or_initialize_by(code: code_for(bundle, line_item))
        row.assign_attributes(
          line_item: line_item,
          kind: 'manual',
          label: Spree.t('product_bundles.discount_label', title: bundle.title),
          amount: -share,
          value: share,
          value_type: 'flat',
          metadata: { 'product_bundle_id' => bundle.prefixed_id }
        )
        row.save!
        row
      end

      # A group the customer has emptied, or one whose saving has gone, leaves
      # no rows behind: the lines are the set, and no set is no saving.
      def remove_stale_rows(written)
        kept = written.map(&:id)

        @order.discounts.select { |row| row.code.to_s.start_with?(CODE_PREFIX) }.
          reject { |row| kept.include?(row.id) }.
          each(&:destroy!)
      end

      def code_for(bundle, line_item)
        "#{CODE_PREFIX}#{bundle.prefixed_id}:#{line_item.id}"
      end

      # Everything this gem writes into an order's discounts is marked by its
      # code, which is how a recomputation finds its own rows and no others.
      CODE_PREFIX = 'bundle:'.freeze
    end
  end
end
