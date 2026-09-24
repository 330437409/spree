module Spree
  module Memberships
    # The member day as its page and the home page's popup both render it: which
    # day the tier's members buy on, whether that is today, what the day earns and
    # what the operator wrote around it.
    #
    # One block for both reads because they are one block — the popup is this plus
    # the `today` the page has no use for — and the day itself is the right's own
    # calendar rather than anything stored
    # (docs/plans/6.1-membership-tiers-and-rights.md).
    class MemberDay
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :right
      attribute :store

      # Whether today is the day, in the store's own calendar. This is what the
      # home page opens its popup on, and it is the same reading the multiplier
      # earns by, so the popup cannot announce a day the ledger does not pay on.
      #
      # @return [Boolean]
      def today?
        right.day?(SpreeMemberships.today_in(store))
      end

      # The day in the customer's own words, **rendered from the weekday rather
      # than typed**: an operator who moves the day to Thursday must not leave the
      # page saying 每周三. A weekday nobody declares — a row written past the model
      # — is no day to print, so it renders nothing rather than the missing-copy
      # markup a translation library would hand a customer.
      #
      # @return [String, nil]
      def line
        weekday = right.weekday
        Spree.t("memberships.weekdays.#{weekday}") if weekday
      end

      # @return [String, nil] the operator's own name for the day
      def day_name
        right.preferred_day_name.presence
      end

      # @return [Integer] what an order paid that day earns
      def times
        right.multiplier
      end

      # @return [BigDecimal, nil] the basket the earning asks for. The threshold is
      #   not a `_money` field: beside the red packet the day prints, a second money
      #   would read as the same kind of thing when one is a condition and the other
      #   is what the day gives
      def minimum_amount
        right.minimum_amount
      end

      # @return [Array<String>] the kinds printed under the threshold
      def qualifying_kinds
        right.qualifying_kinds
      end

      # @return [Boolean] whether the day hands a red packet over
      def rights_red?
        right.red_money.present?
      end

      # @return [BigDecimal, nil]
      def rights_red_money
        right.red_money
      end

      # @return [String, nil]
      def rule
        right.preferred_rules.presence
      end

      # @return [String, nil]
      def share_title
        right.preferred_share_title.presence
      end

      # @return [String, nil]
      def share_icon
        right.preferred_share_icon.presence
      end
    end
  end
end
