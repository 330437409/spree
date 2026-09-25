module Spree
  # What makes a `Spree::CustomerGroup` a tier: its rung on the ladder, what
  # qualifies for it, and how long a term of it lasts.
  #
  # The row has no name and no member list — the group it hangs from has both —
  # which is what keeps it from being a second audience model. Its existence is
  # also how a loyalty tier is told from the wholesale-buyer group that shares
  # the same table (docs/plans/6.1-membership-tiers-and-rights.md).
  class MembershipTierSetting < Spree.base_class
    has_prefix_id :mtier

    include Spree::Metadata
    include Spree::PreferenceSchema
    include Spree::Memberships::PreferenceTypes

    acts_as_paranoid

    belongs_to :customer_group, class_name: 'Spree::CustomerGroup', touch: true
    # The catalogue this tier prices through, when it grants a member price.
    # Named on the tier rather than looked up through the group's assignments:
    # a group can be shown a B2B agreement as well, and the member price must
    # not land on that catalogue's list.
    belongs_to :catalog, class_name: 'Spree::Catalog', optional: true, inverse_of: nil

    # The rights this tier carries, published ones only — the mirror of
    # `MembershipRight#tier_setting`, and the one place the pair is spelled. The
    # scope lives on the association so a preloaded tier answers it without a
    # query of its own, and the order is the ladder's, so every read of a tier's
    # rights lists them the way the operator arranged them.
    has_many :published_rights, -> { published.order(:position, :id) }, class_name: 'Spree::MembershipRight',
                                primary_key: :customer_group_id, foreign_key: :customer_group_id, inverse_of: nil

    # The tier reaches the store through its group: a second tenancy column
    # would be a second thing to keep in step.
    delegate :store, to: :customer_group, allow_nil: true
    delegate :name, :customers, to: :customer_group, allow_nil: true

    # The three pieces ported from spree_crm's membership plan rather than
    # re-invented: the SKU the purchase is priced by, whether a term extends
    # itself when it ends, and how long it may sit lapsed before it leaves the
    # tier's group.
    normalizes :sku, with: ->(value) { value.to_s.strip.presence }
    # The declared preferences are read by their own key, and that key is a
    # symbol: a write arriving from the API carries strings, and a string-keyed
    # row is one every reader answers with the default — silently. The model owns
    # the bridge, so both spellings land on the one the readers use.
    normalizes :preferences, with: ->(value) { value.to_h.deep_symbolize_keys }

    validates :rank, presence: true, numericality: { only_integer: true }
    validates :grace_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validate :sku_unique_per_store, if: -> { sku.present? }
    # Among live rows only, matching the index: a retired settings row is
    # history, and a fresh one for the same group is saved after it is retired.
    validates :customer_group_id, uniqueness: { conditions: -> { where(deleted_at: nil) } }
    validates :validity_days, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :threshold, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

    # The rows the buy page's savings popup renders, in the order the client
    # lays its icons out: what a member saves on the order, the coupons the tier
    # carries, the days it adds and the gift it hands over. Anything else the
    # popup shows is one figure and one paragraph of rules.
    SAVING_SLOTS = %w[order coupon days gift].freeze

    SAVING_SLOTS.each do |slot|
      preference :"saving_#{slot}_title", :string, default: ''
      preference :"saving_#{slot}_content", :string, default: ''
    end
    preference :saving_rules, :string, default: ''
    # What the operator says a member saves in a month. Nothing computes it: what
    # a member saves is their basket times this tier's member price, and neither
    # is known before they spend. Nullable rather than defaulted to zero, so that
    # a tier nobody has written for is not one whose operator wrote nought.
    preference :saving_month_amount, :decimal, nullable: true

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

    # How long one card of this tier lasts, or nil when a term it starts is
    # open-ended.
    #
    # @return [ActiveSupport::Duration, nil]
    def term_length
      validity_days.to_i.positive? ? validity_days.to_i.days : nil
    end

    # How long a term may sit past its end before it leaves the group, or nil
    # when it leaves the moment it ends.
    #
    # @return [ActiveSupport::Duration, nil]
    def grace_period
      grace_days.to_i.positive? ? grace_days.to_i.days : nil
    end

    # The savings popup's rows, in `SAVING_SLOTS` order. A row nobody has
    # written is answered blank rather than left out: the client places its icons
    # by position, so a shorter list would shift them.
    #
    # @return [Array<Hash{String => String}>]
    def saving_rows
      SAVING_SLOTS.map do |slot|
        {
          'title' => public_send(:"preferred_saving_#{slot}_title"),
          'content' => public_send(:"preferred_saving_#{slot}_content")
        }
      end
    end

    # The monthly figure in the notation every other money field of this API
    # uses, or nil when the operator has not written one. `BigDecimal#to_s` on
    # its own renders 0.06 as "0.6e-1", which is not a number to print beside a
    # currency sign.
    #
    # A value that is not a number is answered nil rather than raised over: the
    # validation below refuses one where it is written, and a row written before
    # it existed is still not a reason to fail the whole popup.
    #
    # @return [String, nil]
    def saving_month_amount
      amount = preferred_saving_month_amount
      return unless number_like?(amount)

      BigDecimal(amount.to_s).to_s('F')
    end

    # The list this tier prices through: the catalogue's own, when the
    # catalogue is in effect. Nil when the tier grants no member price.
    #
    # One reader for one definition — the discount the operator reads, the
    # reduction a funded order is measured by and the subsidy's own record all
    # come through here, so they cannot disagree about what a tier's price is.
    #
    # @return [Spree::PriceList, nil]
    def member_price_list
      return nil if catalog.nil? || !catalog.active?

      catalog.price_list
    end

    # The member price this tier grants, as a percentage off the shelf price, or
    # nil when it grants none.
    #
    # Read from the tier's own list rather than stored, so the price a member is
    # charged and the figure an operator sees are the same number — and so a
    # price that stopped applying stops being reported.
    #
    # @return [BigDecimal, nil]
    def member_discount_percentage
      member_price_list&.price_adjustment_percentage&.abs
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
    # record, and this save is what persists the link, so a tier that cannot be
    # saved is never half-priced.
    def apply_member_discount
      return if @pending_member_discount.nil?

      result = Spree::Memberships::SetMemberDiscount.call(
        tier_setting: self, percentage: @pending_member_discount
      )
      return if result.success?

      errors.add(:member_discount_percentage, :invalid, message: refusal_for(result))
      throw :abort
    end

    # The service's own words rather than a bare "is invalid": a percentage its
    # price list refuses, or a catalogue it cannot stand up, is something the
    # operator can act on. A workflow's failed record answers with its own
    # ActiveModel::Errors, which is what the message is built from.
    def refusal_for(result)
      refused = result.error.respond_to?(:value) ? result.error.value : result.error

      if refused.respond_to?(:errors) && refused.errors.any?
        refused.errors.full_messages.to_sentence
      elsif refused.is_a?(Symbol)
        Spree.t(refused, scope: 'memberships.errors', default: refused.to_s.humanize)
      else
        refused.to_s
      end
    end

    # A tier that is retired stops pricing its group: the members keep the group
    # they were in, so a catalogue left in effect would outlive the tier that
    # promised it.
    def switch_off_member_price
      return if catalog.nil?

      Spree::Catalogs::Deactivate.call(catalog: catalog)
    end

    # A SKU identifies a tier within one store's catalog, and the row reaches
    # its store through its group — so the check runs over the join rather than
    # against an index, exactly as a variant's does between sellers.
    def sku_unique_per_store
      taken = self.class.for_store(store).where(sku: sku).where.not(id: id).exists?
      errors.add(:sku, :taken) if taken
    end
  end
end
