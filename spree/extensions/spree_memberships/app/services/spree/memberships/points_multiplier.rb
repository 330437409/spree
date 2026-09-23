module Spree
  module Memberships
    # What a day's rights say an order earns — the seam the points plan left for
    # this gem to point at itself
    # (`Spree::Dependencies.points_multiplier_service`,
    # docs/plans/6.1-points-and-growth-value.md).
    #
    # Only the birthday is answered today. The member day's own dates are the
    # occasion's period, which nothing names yet, and a right whose day cannot be
    # resolved multiplies nothing rather than guessing at a calendar.
    class PointsMultiplier
      prepend Spree::ServiceModule::Base

      # @param order [Spree::Order]
      # @param now [Time] injectable, so a caller that already knows the store's
      #   day — a sweep, a batch — does not read the clock again
      # @return [Spree::ServiceModule::Result] value is the multiplier: the
      #   highest a right asks for today, or 1 when none applies
      def call(order:, now: Time.current)
        success(multiplier_for(order, now))
      end

      private

      # The day is the store's, not the server's: what a merchant in Shanghai calls
      # the 5th must not wait for UTC.
      def multiplier_for(order, now)
        customer = order.customer
        return 1 if customer.nil?

        on = SpreeMemberships.today_in(order.store, now: now)

        rights_for(order.store, customer).map { |right| right.order_multiplier(customer: customer, on: on) }.max || 1
      end

      # @return [Array<Spree::MembershipRight>] empty when the customer is in no
      #   tier
      def rights_for(store, customer)
        tier = Spree::MembershipTierSetting.for_store(store).for_customer(customer)
        tier.nil? ? [] : tier.published_rights.to_a
      end
    end
  end
end
