module Spree
  module Memberships
    # One coupon of a tier's packet: what it is worth, and how it is handed over.
    #
    # The worth is a **preview of a promotion rather than a price** — the wallet
    # refuses to spell a held coupon out because the cart is where it is priced,
    # and this does the opposite job: a sales page has to say 满199减30 before
    # anybody buys. It stays one source of truth by reading the promotion rather
    # than repeating it, which is also why a promotion whose worth it cannot read
    # claims no figure and no type rather than a made-up one
    # (docs/plans/6.1-membership-tiers-and-rights.md).
    class SurpriseCoupon
      include ActiveModel::Model
      include ActiveModel::Attributes

      # The three the client renders a card by.
      MINUS = 'minus'.freeze
      DISCOUNT = 'discount'.freeze
      EXCHANGE = 'exchange'.freeze
      DISCOUNT_TYPES = [MINUS, DISCOUNT, EXCHANGE].freeze

      attribute :promotion
      # What the tier says about this coupon: its two counts and its cadence.
      attribute :settings, default: -> { {} }

      # @return [String, nil] money off a price, a rate off one, or goods handed
      #   over — **nil** when the promotion states no worth this can read, which
      #   is a card showing what the coupon is and how many of it arrive, and
      #   claiming nothing about what it takes off
      def discount_type
        return EXCHANGE if hands_over_goods?
        return DISCOUNT if rate.present?
        return MINUS if amount.present?

        nil
      end

      # @return [BigDecimal, nil] the flat amount taken off, for a money-off one
      def discount_minus
        amount if discount_type == MINUS
      end

      # The rate as the client reads it: 15% off is 8.5折, and a client prints
      # the number rather than the percentage.
      #
      # @return [BigDecimal, nil]
      def discount_rate
        return unless discount_type == DISCOUNT

        (100.to_d - rate) / 10
      end

      # The floor an order has to clear. Rules are ANDed, so where more than one
      # names a floor the higher one is what the coupon asks for — core refuses
      # two rules of a kind on one promotion, so today that means a kind a gem
      # adds beside `ItemTotal`.
      #
      # @return [BigDecimal, nil]
      def limit_amount_min
        floors = promotion.promotion_rules.filter_map do |rule|
          next unless rule.respond_to?(:preferred_amount_min)

          floor = rule.preferred_amount_min.to_d
          floor if floor.positive?
        end
        floors.max
      end

      # @return [Integer] the copies the member may use themselves
      def self_use
        settings[:self_use].to_i
      end

      # @return [Integer] and the copies they may give away
      def friend_use
        settings[:friend_use].to_i
      end

      # @return [String] `once` with the card, or `month` for every month the
      #   term runs — the client's 每月发 badge
      def grant_type
        settings[:grant_type].to_s.presence || Spree::MembershipRights::SurpriseRedEnvelope::DEFAULT_GRANT_TYPE
      end

      # @return [String, nil] the sentence the operator wrote beside the coupon
      def instruction
        settings[:instruction].presence
      end

      # What the coupon is worth to the member in money: the copies of a
      # money-off coupon the packet grants. A rate and an exchange coupon are
      # worth what the basket makes them worth, and no figure is claimed for them.
      #
      # @return [BigDecimal]
      def money_value
        return 0.to_d if discount_minus.nil?

        discount_minus * (self_use + friend_use)
      end

      # @return [Boolean]
      def exchange?
        discount_type == EXCHANGE
      end

      private

      # A promotion may carry several actions and nothing orders them, so every
      # one is read rather than whichever the database happened to return first.
      #
      # @return [Array<Spree::PromotionAction>]
      def actions
        @actions ||= promotion.promotion_actions.order(:id).to_a
      end

      # Only some of core's action classes carry a calculator — the one that hands
      # goods over does not — so each is asked whether it has one rather than
      # assumed to.
      #
      # @return [Array<Spree::Calculator>]
      def calculators
        @calculators ||= actions.filter_map { |action| action.calculator if action.respond_to?(:calculator) }
      end

      # @return [Boolean]
      def hands_over_goods?
        actions.any? { |action| action.is_a?(Spree::Promotion::Actions::CreateLineItems) }
      end

      # A calculator's amount is in a currency of its own, and a figure in
      # another one is not a figure this card can state — the store prints its
      # own, so a coupon priced in a currency this storefront is not shopping in
      # claims none rather than a number that means something else.
      #
      # @return [BigDecimal, nil]
      def amount
        value = calculators.filter_map do |calculator|
          calculator.preferred_amount if calculator.respond_to?(:preferred_amount) && priced_here?(calculator)
        end.first
        amount = value.to_d if value.present?
        amount if amount&.positive?
      end

      # Two spellings, because two calculators carry a percentage. One that
      # carries neither — a tiered rate among them — states none, and the coupon
      # claims none.
      #
      # @return [BigDecimal, nil]
      def rate
        percent = calculators.filter_map { |calculator| percentage_of(calculator) }.first
        percent if percent&.positive? && percent < 100
      end

      # @return [Boolean] whether the amount is in the currency the customer is
      #   shopping in — a calculator that names none is read as this store's
      def priced_here?(calculator)
        return true unless calculator.respond_to?(:preferred_currency)

        currency = calculator.preferred_currency
        currency.blank? || currency.to_s == Spree::Current.currency.to_s
      end

      # @return [BigDecimal, nil]
      def percentage_of(calculator)
        value = if calculator.respond_to?(:preferred_percent)
                  calculator.preferred_percent
                elsif calculator.respond_to?(:preferred_flat_percent)
                  calculator.preferred_flat_percent
                end
        value.to_d if value.present?
      end
    end
  end
end
