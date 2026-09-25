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
    include Spree::Memberships::PreferenceTypes
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

    # A kind's settings are read by their own key, and that key is a symbol: a
    # write arriving with strings — an import, a console, a rake task — is one
    # every reader answers with the default, silently. The model owns the bridge,
    # so both spellings land on the one the readers use.
    normalizes :preferences, with: ->(value) { value.to_h.deep_symbolize_keys }

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

    # Whether this right's occasion falls on a date, for a customer: the question
    # a reader asks when it has no basket — the member centre counting down to a
    # birthday, or asking what a tier grants on a day it is not holding an order
    # for. The date is the caller's, already read in the store's own calendar, the
    # way every store-local fact in this gem is.
    #
    # Every kind answers it: a kind that does not is a right that never applies.
    #
    # @param customer [Object] whose occasion it is
    # @param on [Date]
    # @return [Boolean]
    def applies_on?(customer:, on:)
      false
    end

    # What this right multiplies an order's earn by on a given day, **for a real
    # order**. The day is the kind's own business — a birthday today, a member day
    # on its weekday — so the trigger lives with the kind rather than in the
    # readers that ask, and a kind added later multiplies by declaring itself
    # instead of by being named in two places
    # (`Spree::Dependencies.points_multiplier_service`).
    #
    # The basket is required and not optional: a kind whose occasion also asks what
    # the basket has to reach — the member day earns on orders over a threshold and
    # on nothing else — answers about a basket or not at all, and a reader that has
    # no basket asks `applies_on?` instead of this.
    #
    # Every kind answers this: the reader folds it over a tier's rights, so a kind
    # that does not override it is a right that multiplies nothing.
    #
    # @param customer [Object] whose occasion it is
    # @param on [Date] the day to answer for, in the store's calendar
    # @param order [Spree::Order] whose earn it is
    # @return [Integer] 1 when this right does not apply that day
    def order_multiplier(customer:, on:, order:)
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

    # A day's rate, floored at the ordinary earning of one. Two kinds multiply an
    # earn by one, so the floor is theirs together: the ledger neutralises a
    # non-positive multiplier, and a client shown 0倍 or -2倍 would be reading a
    # number that never applied.
    #
    # A rate nobody can read is the ordinary one rather than an exception: the
    # setting is refused where it is written, and a row written past that — a
    # console, an import — is still not a reason to fail a member's page.
    #
    # @param value [Object] whatever the kind's own preference holds
    # @return [Integer]
    def floored_multiplier(value)
      return 1 unless number_like?(value)

      amount = value.to_i
      amount > 1 ? amount : 1
    end

    # The promotions a kind's own preference names, in the order it names them,
    # read in one query with what reading them needs. Three kinds keep such a
    # list — the entry coupon, the annual gift and the surprise packet — so it is
    # spelled once; a promotion an operator has since deleted drops out rather
    # than failing the read.
    #
    # The actions and rules are preloaded but their **calculators are not**: only
    # some actions carry one — the one that hands goods over does not — and an
    # association a subclass does not define cannot be preloaded for a whole
    # relation. A reader that needs one loads it, which is one query for a page
    # that quotes a figure and none for a page that does not.
    #
    # Read through *this* row's store, the way the write is checked: the rows are
    # guarded where an operator writes them, and reading through the store as
    # well is what keeps a row written before that guard from naming another
    # store's promotion to a customer.
    #
    # @param prefixed_ids [Array<String>]
    # @return [Array<Spree::Promotion>]
    def promotions_for(prefixed_ids)
      ids = Array(prefixed_ids).filter_map { |id| Spree::Promotion.decode_prefixed_id(id.to_s) }.uniq
      return [] if ids.empty?

      found = Spree::Promotion.where(id: ids, store: store).
              includes(:promotion_rules, :promotion_actions).
              index_by { |promotion| promotion.id.to_s }
      ids.filter_map { |id| found[id.to_s] }
    end

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
