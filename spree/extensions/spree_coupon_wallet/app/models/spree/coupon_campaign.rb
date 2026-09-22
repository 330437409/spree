module Spree
  # A way a coupon reaches a customer: a draw they take part in, a welcome
  # coupon for a new account, a site's own handout.
  #
  # The campaign says which promotion's codes it gives away and on what terms.
  # It never decides what a coupon is worth — that is the promotion's — and it
  # never applies one, because `carts/:cart_id/discount_codes` is the single
  # application path (docs/plans/6.1-coupon-wallet.md).
  #
  # Its kinds are registered subclasses, each declaring its own settings as
  # preferences and its own eligibility, so a new way to hand a coupon over is
  # a class and a registration rather than a column.
  class CouponCampaign < Spree.base_class
    include Spree::SingleStoreResource
    include Spree::HasStatus
    include Spree::Metadata
    include Spree::PreferenceSchema

    publishes_lifecycle_events

    acts_as_paranoid

    has_prefix_id :camp

    has_status :draft, :active, :paused, default: :draft

    registers_subclasses_via { SpreeCouponWallet.coupon_campaign_types }

    belongs_to :promotion, class_name: 'Spree::Promotion'

    # Every kind hands over one coupon unless it says otherwise, and a coupon
    # lives as long as the operator says after it arrives — the expiry is set
    # when it is handed over, not when the campaign was written.
    preference :limit_per_customer, :integer, default: 1
    preference :valid_for_days, :integer, nullable: true

    validates :name, presence: true
    validate :type_must_be_registered
    validate :promotion_must_hand_out_codes
    validate :promotion_must_belong_to_the_store

    # @return [Array<Class>] the kinds a campaign may be
    def self.available_types
      SpreeCouponWallet.coupon_campaign_types
    end

    # @return [String] the name an operator picks this kind by
    def self.human_name
      Spree.t("coupon_campaign_types.#{api_type}.name", default: name.demodulize.titleize)
    end

    # @return [Boolean] whether a draw may be taken from it right now
    def running?
      active? && started? && !ended?
    end

    # @return [Boolean] whether its window has opened
    def started?
      starts_at.nil? || starts_at <= Time.current
    end

    # @return [Boolean] whether its window has closed
    def ended?
      expires_at.present? && expires_at <= Time.current
    end

    # Whether this campaign may hand a coupon to this customer. A kind that
    # narrows who may take one overrides it.
    #
    # @param customer [Spree.user_class]
    # @return [Boolean]
    def eligible_for?(_customer)
      true
    end

    # When a coupon handed over now lapses, or nil when it never does.
    #
    # @return [Time, nil]
    def expiry_for_grant
      return nil if preferred_valid_for_days.blank?

      preferred_valid_for_days.to_i.days.from_now
    end

    private

    def type_must_be_registered
      return if self.type.present? && self.class.available_types.any? { |kind| kind.to_s == type }

      errors.add(:type, :not_a_registered_coupon_campaign,
                 message: Spree.t('errors.messages.not_a_registered_coupon_campaign'))
    end

    # Only a multi-codes promotion has code rows to hand over: a single-code
    # promotion's `code` is the promotion's own, and a customer cannot hold it.
    def promotion_must_hand_out_codes
      return if promotion.nil? || promotion.multi_codes?

      errors.add(:promotion, :coupon_campaign_needs_a_code_pool,
                 message: Spree.t('errors.messages.coupon_campaign_needs_a_code_pool'))
    end

    # Another store's promotion would hand this store's customers a coupon the
    # store cannot honour.
    def promotion_must_belong_to_the_store
      return if promotion.nil? || store_id.nil? || promotion.store_id == store_id

      errors.add(:promotion, :coupon_campaign_promotion_store_mismatch,
                 message: Spree.t('errors.messages.coupon_campaign_promotion_store_mismatch'))
    end
  end
end
