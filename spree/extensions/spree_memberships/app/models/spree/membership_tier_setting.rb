module Spree
  # What makes a `Spree::CustomerGroup` a tier: its rung on the ladder, what
  # qualifies for it, and how long a term of it lasts.
  #
  # The row has no name and no member list — the group it hangs from has both —
  # which is what keeps it from being a second audience model. Its existence is
  # also how a loyalty tier is told from the wholesale-buyer group that shares
  # the same table (docs/plans/6.1-membership-tiers-and-rights.md).
  class MembershipTierSetting < Spree.base_class
    include Spree::Metadata

    acts_as_paranoid

    belongs_to :customer_group, class_name: 'Spree::CustomerGroup', touch: true
    # The catalogue this tier prices through, when it grants a member price.
    # Named on the tier rather than looked up through the group's assignments:
    # a group can be shown a B2B agreement as well, and the member price must
    # not land on that catalogue's list.
    belongs_to :catalog, class_name: 'Spree::Catalog', optional: true, inverse_of: nil

    # The tier reaches the store through its group: a second tenancy column
    # would be a second thing to keep in step.
    delegate :store, to: :customer_group, allow_nil: true
    delegate :name, :customers, to: :customer_group, allow_nil: true

    validates :rank, presence: true, numericality: { only_integer: true }
    # Among live rows only, matching the index: a retired settings row is
    # history, and a fresh one for the same group is saved after it is retired.
    validates :customer_group_id, uniqueness: { conditions: -> { where(deleted_at: nil) } }
    validates :validity_days, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :threshold, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

    scope :ordered, -> { order(:rank, :id) }
    scope :for_store, ->(store) { joins(:customer_group).where(spree_customer_groups: { store_id: store&.id }) }

    # The highest tier this customer holds, or nil when they hold none.
    #
    # One writer keeps anybody on one tier, so more than one is a setup error,
    # and the honest reading of it is the better tier rather than whichever one
    # happened to sort first.
    #
    # @param customer [Object, nil]
    # @return [Spree::MembershipTierSetting, nil]
    def self.for_customer(customer)
      return nil if customer.nil?

      where(customer_group_id: customer.customer_groups.select(:id)).reorder(rank: :desc).first
    end

    # What a customer at this tier has spent to be here, or nil when the tier is
    # sold rather than earned.
    #
    # @return [BigDecimal, nil]
    def qualifies?(amount)
      threshold.present? && amount.to_d >= threshold
    end

    # The member price this tier grants, as a percentage off the shelf price, or
    # nil when it grants none.
    #
    # Read from the tier's own catalogue rather than stored, so the price a
    # member is charged and the figure an operator sees are the same number —
    # and so a catalogue that stopped applying stops being reported.
    #
    # @return [BigDecimal, nil]
    def member_discount_percentage
      return nil if catalog.nil? || !catalog.active?

      catalog.price_list&.price_adjustment_percentage&.abs
    end

    # Assigning stages the price; it is written with the save, so a tier that
    # cannot be saved is never half-priced.
    def member_discount_percentage=(value)
      @pending_member_discount = value.presence
    end

    private

    before_save :apply_member_discount
    after_destroy :switch_off_member_price

    # The member price lives on a catalogue and its owned list, so writing it is
    # a service rather than a column (Design Details, "Member pricing is the
    # tier's catalog"). Nil and zero take it out of effect.
    #
    # The service assigns the catalogue it stands up — or found — on this
    # record, and this save is what persists the link.
    def apply_member_discount
      return if @pending_member_discount.nil?

      result = Spree::Memberships::SetMemberDiscount.call(
        tier_setting: self, percentage: @pending_member_discount
      )
      return if result.success?

      errors.add(:member_discount_percentage, :invalid)
      throw :abort
    end

    # A tier that is retired stops pricing its group: the members keep the group
    # they were in, so a catalogue left in effect would outlive the tier that
    # promised it.
    def switch_off_member_price
      return if catalog.nil?

      Spree::Catalogs::Deactivate.call(catalog: catalog)
    end
  end
end
