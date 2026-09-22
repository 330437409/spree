module Spree
  module Points
    # What a paid order earns.
    #
    # One number for both balances: 积分 and 成长值 are earned by the same
    # events and the plan's table of inputs does not distinguish them (ruled
    # 2026-09-22).
    #
    #   base       the amount actually paid over the store's earn rate —
    #              "按照优惠后（扣除积分抵扣、优惠券等活动）实付金额进行换算", so
    #              a coupon, a promotion and a points deduction all reduce it,
    #              which is why the order's own total is the figure
    #   extra      each line's own 商品积分, from the good's Custom Fields and
    #              capped by that good's own cap
    #   threshold  below the store's minimum, nothing is earned at all
    #   multiplier what a day's rights say today — none until the membership
    #              gem is built, which points the seam at its own service
    #
    # Nothing is written here: the subscriber credits through the ledger, and
    # this answers one number.
    #
    # It takes the caller's word that the order is paid, because the event is
    # the only trustworthy gate: `order.paid` fires from the payment's own
    # commit, and `order.paid?` reads `payment_total`, which core's own comment
    # says is written later than that event — asking it here would silently
    # earn nothing (`spree/core/app/models/spree/payment/custom_events.rb:39`).
    class Earning
      prepend Spree::ServiceModule::Base

      # The two names an operator fills in per product, in the `points`
      # namespace of that product's Custom Fields. Both live on the product
      # rather than on the line: the line's own figure is derived from them and
      # the quantity, and storing it would be a second copy that drifts.
      EXTRA_PER_UNIT = 'points.extra_per_unit'.freeze
      LINE_CAP = 'points.line_cap'.freeze

      # @param order [Spree::Order]
      # @return [Spree::ServiceModule::Result] value is the integer earned, 0
      #   when the order earns nothing
      def call(order:)
        rate = order.store.preferred_points_earn_rate.to_d
        return success(0) unless rate.positive?

        paid = order.total.to_d
        return success(0) if paid < order.store.preferred_points_minimum_order_amount.to_d

        earned = ((paid / rate) + extra(order)) * multiplier(order)

        success(earned.floor.clamp(0, Float::INFINITY).to_i)
      end

      private

      # 商品积分: what each good adds on top, per the quantity bought, held to
      # the cap that good carries. A good with no setting adds nothing.
      #
      # @return [BigDecimal]
      def extra(order)
        lines(order).sum(0.to_d) do |line|
          add_on(line)
        end
      end

      # @return [BigDecimal]
      def add_on(line)
        product = line.variant&.product
        return 0.to_d if product.nil?

        per_unit = amount(product, EXTRA_PER_UNIT)
        return 0.to_d unless per_unit&.positive?

        earned = per_unit * line.quantity.to_i
        cap = amount(product, LINE_CAP)

        # A cap of zero is no cap rather than a cap of nothing: an operator who
        # leaves the field empty should not silently lose the goods' own points.
        cap&.positive? ? [earned, cap].min : earned
      end

      # The value is read off the association the preload already filled rather
      # than through `get_custom_field`, which is its own JOIN: an earn runs for
      # every paid order, and a query per line per name is a query per line too
      # many.
      def amount(product, key)
        namespace, name = key.split('.')
        field = product.custom_fields.find do |candidate|
          candidate.custom_field_definition&.namespace == namespace &&
            candidate.custom_field_definition&.key == name
        end

        field&.value.to_d
      rescue TypeError, ArgumentError
        # A custom field an operator typed as text rather than as a number is
        # not a reason to lose an order's earn.
        nil
      end

      # The lines with everything the earn reads already in hand: the product
      # for the goods, and its custom fields for the two names above.
      def lines(order)
        order.line_items.includes(variant: { product: :custom_fields })
      end

      # The seam answers a number — or a service answering with one, which is
      # how everything else in this repository answers (`ServiceModule::Result`
      # carries the number as its value).
      def multiplier(order)
        service = Spree.points_multiplier_service
        return 1.to_d if service.blank?

        answer = service.call(order: order)
        answer = answer.value if answer.respond_to?(:value)
        value = answer.to_d

        value.positive? ? value : 1.to_d
      end
    end
  end
end
