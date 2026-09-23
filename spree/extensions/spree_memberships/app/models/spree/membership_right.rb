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
    # One of each kind per tier. Among live rows only, matching the index — a
    # retired row is history, and a replacement is saved before the row it
    # supersedes is retired.
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
      promotion = Spree::Promotion.find_by_prefix_id(preferred_promotion_id)
      return errors.add(:preferences, :invalid) if promotion.nil?
      return if store.nil? || promotion.store_id == store.id

      errors.add(:preferences, :invalid)
    end

    def type_must_be_registered
      return if self.class.available_types.any? { |kind| kind.to_s == type }

      errors.add(:type, :not_a_registered_membership_right,
                 message: Spree.t('errors.messages.not_a_registered_membership_right'))
    end
  end
end
