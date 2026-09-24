module Spree
  # The member centre's banner: the picture a tier's members see at the top of
  # the member centre, and the tap targets laid over it.
  #
  # It hangs from the tier's group rather than carrying a tenancy of its own —
  # the group already has the store, and a second copy of it is a second thing
  # to drift — and its areas are the operator's own coordinates in rem, the unit
  # the client lays them out in, so what an operator places is what renders
  # (docs/plans/6.1-membership-tiers-and-rights.md).
  class MembershipBanner < Spree.base_class
    has_prefix_id :mbanner

    include Spree::Metadata

    acts_as_paranoid

    belongs_to :customer_group, class_name: 'Spree::CustomerGroup', touch: true

    # Reaches the store through the group it hangs from, exactly as a right does.
    delegate :store, to: :customer_group, allow_nil: true

    # An empty list rather than nil: a banner with nothing over it is a banner
    # whose picture is the whole of it, and that is the state a new one is in.
    #
    # Normalized on the way in because a request hands over its own
    # `ActionController::Parameters`, and a JSON column must hold plain data.
    attribute :areas, default: []

    normalizes :areas, with: ->(areas) {
      Array.wrap(areas).map { |area| area.respond_to?(:to_h) ? area.to_h : area }
    }

    validates :pic, presence: true
    # One banner per tier, among live rows only, matching the index.
    validates :customer_group_id, uniqueness: { conditions: -> { where(deleted_at: nil) } }
    validate :areas_must_be_placeable

    # The placeable areas of a banner: each one carries the style its coordinates
    # are written in and the link it opens. Anything else is a row the client
    # would render as an invisible tap target.
    #
    # Over the API, permitted parameters already drop an unknown key and an area
    # that is not a hash; the rest of the check is for the writers that are not
    # the API — a console, a seed, an import.
    AREA_KEYS = %w[area_rem link name].freeze

    # @param customer [Object, nil] whose tier resolves the banner
    # @param store [Spree::Store, nil]
    # @return [Spree::MembershipBanner, nil] nil when they are in no tier, or
    #   their tier carries no banner
    def self.for_customer(customer, store: Spree::Current.store)
      tier = Spree::MembershipTierSetting.for_store(store).for_customer(customer)
      return nil if tier.nil?

      find_by(customer_group_id: tier.customer_group_id)
    end

    private

    def areas_must_be_placeable
      return if areas.blank?

      errors.add(:areas, :invalid) unless areas.is_a?(Array) && areas.all? { |area| placeable?(area) }
    end

    def placeable?(area)
      return false unless area.is_a?(Hash)

      area = area.with_indifferent_access

      area[:area_rem].present? && area[:link].present? && (area.keys.map(&:to_s) - AREA_KEYS).empty?
    end
  end
end
