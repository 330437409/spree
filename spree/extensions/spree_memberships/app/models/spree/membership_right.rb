module Spree
  # What a tier grants.
  #
  # A right is an entitlement rather than a condition — the tier it belongs to
  # *is* the condition — so it has the shape of `Spree::PromotionAction` and not
  # of `Spree::PromotionRule`, and there is no matcher to write. What varies
  # between kinds is what they grant and how they present, and that is the axis
  # this repository types: a kind is a registered subclass with its own
  # preferences, so a kind a gem adds needs no column and no change to any read
  # (docs/plans/6.1-membership-tiers-and-rights.md).
  class MembershipRight < Spree.base_class
    include Spree::PreferenceSchema
    include Spree::Metadata

    acts_as_paranoid
    acts_as_list scope: :customer_group

    has_prefix_id :mright

    belongs_to :customer_group, class_name: 'Spree::CustomerGroup', touch: true

    # The settings row of the tier this right hangs on. A `CustomerGroup` is
    # core's and has no association to this gem's rows, so the pair is spelled
    # out here rather than reopened there — the shape core itself uses where two
    # tables are related without an association.
    has_one :tier_setting, class_name: 'Spree::MembershipTierSetting',
                           primary_key: :customer_group_id, foreign_key: :customer_group_id,
                           inverse_of: nil

    # Reaches the store through its tier, exactly as a commission rule reaches
    # it through its rate: no second tenancy column, and nothing to keep in sync.
    delegate :store, to: :customer_group, allow_nil: true

    registers_subclasses_via { SpreeMemberships.membership_rights }

    validates :type, presence: true
    # One of each kind per tier. Among live rows only, matching the index — the
    # row a replacement supersedes is retired first, because a retired row is
    # history while a live duplicate is refused.
    validates :type, uniqueness: {
      scope: [:customer_group_id, *spree_base_uniqueness_scope],
      conditions: -> { where(deleted_at: nil) }
    }
    validate :type_must_be_registered
    # Checked where the operator writes it rather than where the member activates:
    # a promotion that is gone must not fail somebody's activation after they have
    # been told they are a member. Read only while the preference is being
    # written, so a right whose promotion has since gone can still be retired.
    validate :promotion_must_belong_to_the_store, if: -> { preferred_promotion_id.present? && will_save_change_to_preferences? }

    # The promotion a coupon kind draws from when a member enters — the one
    # preference every kind carries, because the reader below is the base's. A
    # kind that hands over no coupon leaves it unset.
    preference :promotion_id, :string, nullable: true

    scope :published, -> { where(published: true) }

    # The rights this store's ladder carries. A right carries no tenancy column
    # of its own — it reaches the store through its tier — so this is spelled
    # from the model rather than through an association, and every store-scoped
    # read of a right shares it.
    scope :for_store, ->(store) {
      where(customer_group_id: Spree::MembershipTierSetting.for_store(store).select(:customer_group_id))
    }

    # @return [Array<Class>] the kinds a right may be
    def self.available_types
      SpreeMemberships.membership_rights
    end

    # @return [String] the name an operator picks this kind by
    def self.human_name
      Spree.t("membership_right_types.#{api_type}.name", default: name.demodulize.titleize)
    end

    # @return [String] what the right grants, shown beside the name in a picker
    def self.description
      Spree.t("membership_right_types.#{api_type}.description", default: '')
    end

    # The member-centre panel this kind appears in, as the client's own key. A
    # kind that declares an existing panel joins it with no change to the read
    # that groups them, and a kind that declares none is a right with no panel in
    # this client — which is the honest outcome, not a gap to paper over.
    #
    # @return [String, nil]
    def self.presents_as
      nil
    end

    # What entering the tier hands over, read once when the card is activated:
    # the two sides of the client's 恭喜升级 bag. A kind that hands over nothing
    # answers nil to both and the bag skips it.
    #
    # Two readers rather than one hash, because the ledger and the coupon wallet
    # take different arguments and neither is the other's shape.
    #
    # @return [Integer, nil] points credited on entry
    def entry_points
      nil
    end

    # @return [String, nil] the promotion a coupon is drawn from, by its prefixed
    #   id. Read from the preference every kind carries; a kind that hands over no
    #   coupon leaves it unset, which is nil here.
    def entry_coupon
      preferred_promotion_id.presence
    end

    # What this kind contributes to the member centre beyond the right itself,
    # answered per customer because what it contributes is a state of theirs
    # rather than a setting of the tier's: which of the annual gift's coupons
    # they have taken, and what is left of the year's allowance. Most kinds
    # contribute nothing and answer nil here.
    #
    # @param customer [Object] the member the read is for
    # @param store [Spree::Store]
    # @return [Object, nil] the payload, for the API to serialize by its shape
    def member_payload(customer:, store:)
      nil
    end

    # What this right multiplies an order's earn by on a given day. The day is the
    # kind's own business — a birthday today, a member day once its period exists —
    # so the trigger lives with the kind rather than in the readers that ask, and a
    # kind added later multiplies by declaring itself instead of by being named in
    # two places (`Spree::Dependencies.points_multiplier_service`).
    #
    # Every kind answers this: the readers fold it over a tier's rights, so a kind
    # that does not override it is a right that multiplies nothing.
    #
    # @param customer [Object] whose occasion it is
    # @param on [Date] the day to answer for, in the store's calendar
    # @return [Integer] 1 when this right does not apply that day
    def order_multiplier(customer:, on:)
      1
    end

    # The display name a customer reads. The row's own copy wins, so an operator
    # can call the same right something else at another tier without a release.
    #
    # @return [String]
    def display_name
      name.presence || self.class.human_name
    end

    private

    # Keyed on `preferences`, which is the field an operator's form writes — and
    # scoped to the store, because a pool in another store's promotion is a code
    # this tier must not draw.
    def promotion_must_belong_to_the_store
      return if promotion_of_this_store?(preferred_promotion_id)

      errors.add(:preferences, :invalid)
    end

    # @param promotion_id [String] a promotion's prefixed id
    # @return [Boolean] whether this store runs that promotion — the shared half
    #   of the entry coupon's check and of a kind that names its own coupons
    def promotion_of_this_store?(promotion_id)
      promotion = Spree::Promotion.find_by_prefix_id(promotion_id)
      return false if promotion.nil?

      store.nil? || promotion.store_id == store.id
    end

    def type_must_be_registered
      return if self.class.available_types.any? { |kind| kind.to_s == type }

      errors.add(:type, :not_a_registered_membership_right,
                 message: Spree.t('errors.messages.not_a_registered_membership_right'))
    end
  end
end
