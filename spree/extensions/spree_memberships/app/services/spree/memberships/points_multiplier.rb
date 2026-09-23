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
      # @return [Spree::ServiceModule::Result] value is the multiplier: what the
      #   birthday right says, or 1 when nothing applies
      def call(order:)
        success(multiplier_for(order))
      end

      private

      def multiplier_for(order)
        customer = order.customer
        return 1 if customer.nil? || customer.birthday.nil?
        return 1 unless today?(order.store, customer.birthday)

        right = birthday_right(order.store, customer)
        right.nil? ? 1 : right.multiplier
      end

      # A birthday is the customer's own date in the store's calendar, not the
      # server's: what a merchant in Shanghai calls the 5th must not wait for UTC.
      def today?(store, birthday)
        today = Time.current.in_time_zone(zone_for(store)).to_date

        birthday.month == today.month && birthday.day == today.day
      end

      def zone_for(store)
        Time.find_zone(store&.preferred_timezone) || Time.zone
      end

      # @return [Spree::MembershipRights::BirthdayDoubleIntegral, nil] nil when
      #   the customer is in no tier, or their tier does not carry the right
      def birthday_right(store, customer)
        tier = Spree::MembershipTierSetting.for_store(store).for_customer(customer)
        return nil if tier.nil?

        tier.published_rights.detect do |right|
          right.is_a?(Spree::MembershipRights::BirthdayDoubleIntegral)
        end
      end
    end
  end
end
