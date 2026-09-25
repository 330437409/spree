module Spree
  module MembershipRights
    # Double points on the customer's birthday, for the membership plan's
    # multiplier seam (docs/plans/6.1-points-and-growth-value.md). The day itself
    # is the customer's own `birthday` column, and the grant that spends this is
    # an occasion of this kind.
    class BirthdayDoubleIntegral < Spree::MembershipRight
      preference :multiplier, :integer, default: 2

      # @return [Integer] what the day's earnings are multiplied by, never less
      #   than the ordinary rate
      def multiplier
        floored_multiplier(preferred_multiplier)
      end

      # The customer's birthday, in the store's calendar. A 29 February birthday
      # is celebrated on the last day of its month in a year that has no 29th —
      # which is also the day the member centre counts down to.
      #
      # @param customer [Object]
      # @param on [Date]
      # @return [Boolean]
      def applies_on?(customer:, on:)
        birthday = customer&.birthday
        return false if birthday.nil?

        on.month == birthday.month && on.day == celebrated_day(birthday, on)
      end

      # @return [Integer] the multiplier on the day, 1 otherwise
      def order_multiplier(customer:, on:, order:)
        applies_on?(customer: customer, on: on) ? multiplier : 1
      end

      private

      def celebrated_day(birthday, on)
        [birthday.day, Date.new(on.year, birthday.month, -1).day].min
      end
    end
  end
end
