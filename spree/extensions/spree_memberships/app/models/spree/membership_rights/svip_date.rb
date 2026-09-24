module Spree
  module MembershipRights
    # Member day: a weekday the tier's members buy on better terms.
    #
    # The day is the occasion's own period, which is why this kind is the one that
    # declares a calendar rather than a thing handed over: `day?` is what the
    # multiplier folds, and the date is what a grant keyed on the day would count
    # (docs/plans/6.1-membership-tiers-and-rights.md).
    class SvipDate < Spree::MembershipRight
      # The weekdays as `Date::DAYNAMES` writes them, downcased: the operator picks
      # one and the store's own calendar decides which date that is.
      WEEKDAYS = Date::DAYNAMES.map(&:downcase).freeze

      # The preferences that carry money, and the one rule they share: a price is
      # positive or unset. Declared as a list the way the savings slots are, so
      # the reader and the check each exist once and cannot drift apart.
      MONEY_PREFERENCES = %i[minimum_amount rights_red_money].freeze

      preference :weekday, :string, default: WEEKDAYS.first, in: WEEKDAYS
      # What an order paid on the day earns, and the basket it has to reach first —
      # the page prints both, and the reader enforces both.
      preference :multiplier, :integer, default: 2
      preference :minimum_amount, :decimal, nullable: true
      # The red packet the day prints, and the copy around it.
      preference :rights_red_money, :decimal, nullable: true
      preference :day_name, :string, default: ''
      preference :qualifying_kinds, :array, default: []
      preference :rules, :string, default: ''
      preference :share_title, :string, default: ''
      preference :share_icon, :string, default: ''

      validate :weekday_must_be_a_day_of_the_week, if: -> { new_record? || will_save_change_to_preferences? }
      validate :money_preferences_must_be_prices, if: -> { new_record? || will_save_change_to_preferences? }

      # 会员日
      def self.presents_as
        'userVipDayPageVo'
      end

      # The day the customer's tier runs, or nil when they hold no tier or their
      # tier declares none. One home for the question both of this day's reads ask,
      # so the page and the check cannot answer about two different tiers.
      #
      # @param customer [Object]
      # @param store [Spree::Store]
      # @return [Spree::Memberships::MemberDay, nil]
      def self.for_customer(customer, store: Spree::Current.store)
        return nil if customer.nil?

        # The tier lookup the plan records as deferred: this is its fifth call
        # site, and the four beside it collapse into one reader when a slice next
        # opens one of them (docs/plans/6.1-membership-tiers-and-rights.md).
        tier = Spree::MembershipTierSetting.for_store(store).for_customer(customer)
        right = tier&.published_rights&.detect { |candidate| candidate.is_a?(self) }

        right&.day(store: store)
      end

      # @return [Integer] what the day multiplies an earn by, never less than the
      #   ordinary rate
      def multiplier
        floored_multiplier(preferred_multiplier)
      end

      # @return [BigDecimal, nil] what the basket has to reach for the day's
      #   earning to apply, nil when it applies to any basket
      def minimum_amount
        money_preference(:minimum_amount)
      end

      # @return [BigDecimal, nil] the red packet the day prints
      def red_money
        money_preference(:rights_red_money)
      end

      # @return [Array<String>] the kinds printed under the threshold
      def qualifying_kinds
        Array(preferred_qualifying_kinds).map(&:to_s).compact_blank
      end

      # The day as the member-day page and the home page's popup both render it —
      # the same block, since the popup is this plus a `today` the page has no use
      # for.
      #
      # @param store [Spree::Store]
      # @return [Spree::Memberships::MemberDay]
      def day(store:)
        Spree::Memberships::MemberDay.new(right: self, store: store)
      end

      # @return [String, nil] the weekday as the calendar writes it, nil for one
      #   nobody declares: a row written past the model is not a day that comes
      #   round, and nothing renders it as one
      def weekday
        value = preferred_weekday.to_s.downcase
        value if WEEKDAYS.include?(value)
      end

      # Whether a date falls on this tier's member day. The date is the caller's,
      # already read in the store's own calendar — the same reading everything else
      # in this gem does, so a merchant in Shanghai does not wait for UTC.
      #
      # @param on [Date, nil]
      # @return [Boolean]
      def day?(on)
        declared = weekday
        return false if on.nil? || declared.nil?

        Date::DAYNAMES[on.wday].casecmp?(declared)
      end

      # Whether the day is the date's — the cart-free question, answered by the day
      # itself.
      #
      # @param customer [Object] unused: the day is the tier's, not the customer's
      # @param on [Date]
      # @return [Boolean]
      def applies_on?(customer:, on:)
        day?(on)
      end

      # The day's earning, and nothing on any other day: an order under the basket
      # the page asks for earns the ordinary rate, which is what the page says.
      #
      # @param customer [Object] unused: the day is the tier's, not the customer's
      # @param on [Date]
      # @param order [Spree::Order] whose basket the day asks about
      # @return [Integer]
      def order_multiplier(customer:, on:, order:)
        return 1 unless day?(on)
        return 1 if minimum_amount.present? && order.total.to_d < minimum_amount

        multiplier
      end

      private

      # A weekday nothing matches is the day that never comes: the operator keeps
      # waiting and the page keeps saying a day that the calendar never reaches.
      # Refused where it is written.
      def weekday_must_be_a_day_of_the_week
        return if WEEKDAYS.include?(preferred_weekday.to_s.downcase)

        errors.add(:preferences, :invalid)
      end

      # A threshold nobody can clear and a red packet worth less than nothing are
      # both operator errors, refused where they are written — and refused for
      # every declared money preference, so the list above is the only place one
      # is added.
      def money_preferences_must_be_prices
        MONEY_PREFERENCES.each do |key|
          next if public_send(:"preferred_#{key}").blank? || money_preference(key).present?

          errors.add(:preferences, :invalid)
        end
      end

      # @return [BigDecimal, nil] a money preference, or nil when nobody set one:
      #   zero and below are not prices, and an unset preference is no constraint
      def money_preference(key)
        amount = public_send(:"preferred_#{key}").to_d
        amount if amount.positive?
      end
    end
  end
end
