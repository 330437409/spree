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

    # The display name a customer reads. The row's own copy wins, so an operator
    # can call the same right something else at another tier without a release.
    #
    # @return [String]
    def display_name
      name.presence || self.class.human_name
    end

    private

    def type_must_be_registered
      return if self.class.available_types.any? { |kind| kind.to_s == type }

      errors.add(:type, :not_a_registered_membership_right,
                 message: Spree.t('errors.messages.not_a_registered_membership_right'))
    end
  end
end
