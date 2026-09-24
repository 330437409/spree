module Spree
  module Memberships
    # One coupon of a tier's packet: what it is worth, and how it is handed over.
    #
    # The worth is a **preview of a promotion rather than a price** — the wallet
    # refuses to spell a held coupon out because the cart is where it is priced,
    # and this does the opposite job: a sales page has to say 满199减30 before
    # anybody buys. It stays one source of truth by reading the promotion rather
    # than repeating it, which is also why a promotion of no recognisable shape
    # answers no figure at all rather than a made-up one
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
      # What the tier's right says about this coupon: its two counts and its
      # cadence. An unlisted coupon reads empty.
      attribute :settings, default: -> { {} }

      # @return [String] money off a price, a rate off one, or goods handed over
      def discount_type
        return EXCHANGE if hands_over_goods?
        return DISCOUNT if rate.present?

        MINUS
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
        return nil if rate.nil?

        (100.to_d - rate) / 10
      end

      # @return [BigDecimal, nil] what an order has to reach before it applies
      def limit_amount_min
        minimum
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
        settings[:grant_type].to_s.presence || Spree::MembershipRights::SurpriseRedEnvelope::GRANT_TYPES.first
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

      # What does the work, and a promotion may carry several actions. The first
      # is the one an operator's form writes.
      #
      # @return [Spree::PromotionAction, nil]
      def action
        @action ||= promotion.actions.first
      end

      # Goods rather than money: the action that hands a product over is the
      # coupon the client calls an exchange.
      #
      # @return [Boolean]
      def hands_over_goods?
        action.is_a?(Spree::Promotion::Actions::CreateLineItems)
      end

      # Where an operator sets the amount or the rate, so where it is read from.
      #
      # @return [Spree::Calculator, nil]
      def calculator
        action&.calculator
      end

      # @return [BigDecimal, nil]
      def amount
        return unless calculator.respond_to?(:preferred_amount)

        value = calculator.preferred_amount
        value.to_d if value.present? && value.to_d.positive?
      end

      # Two spellings, because two calculators carry a percentage. One that
      # carries neither — a tiered rate among them — answers nil, and the coupon
      # renders with no figure.
      #
      # @return [BigDecimal, nil]
      def rate
        percent = if calculator.respond_to?(:preferred_percent)
                    calculator.preferred_percent
                  elsif calculator.respond_to?(:preferred_flat_percent)
                    calculator.preferred_flat_percent
                  end
        return if percent.blank?

        percent = percent.to_d
        percent if percent.positive? && percent < 100
      end

      # The first rule that names what an order has to reach — how an operator
      # writes "over this much", and what the client prints as the threshold.
      # Asked as a question about a preference rather than as a class, so a rule
      # a gem adds that spells a minimum the same way is read the same way.
      #
      # @return [BigDecimal, nil]
      def minimum
        rule = promotion.rules.detect do |candidate|
          candidate.respond_to?(:preferred_amount_min) && candidate.preferred_amount_min.to_d.positive?
        end
        return if rule.nil?

        rule.preferred_amount_min.to_d
      end
    end
  end
end
