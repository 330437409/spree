module Spree
  # The coupon a customer holds: the side table of one core `Spree::Grant`.
  #
  # The primitive owns who is owed, when it lapses and whether it is still
  # owed; this row owns which code it is, which campaign handed it over and how
  # it arrived. There is deliberately no `store_id` here — the grant carries
  # the store, and a second copy of a tenancy is a second thing to drift
  # (docs/plans/6.1-coupon-wallet.md).
  class CouponHolding < Spree.base_class
    include Spree::Metadata

    publishes_lifecycle_events

    acts_as_paranoid

    has_prefix_id :chold

    # How the customer came by it. The wallet filters on this, which is why it
    # is a column rather than a kind's own setting.
    SOURCES = %w[draw exchange purchase gift admin sms].freeze

    belongs_to :grant, class_name: 'Spree::Grant'
    belongs_to :coupon_code, class_name: 'Spree::CouponCode'
    belongs_to :campaign, class_name: 'Spree::CouponCampaign', optional: true

    validates :source, presence: true, inclusion: { in: SOURCES }
    validates :grant_id, uniqueness: true
    validates :coupon_code_id, uniqueness: true

    delegate :customer, :customer_id, :status, :expires_at, :granted_at, :store, :store_id, to: :grant

    # The grant's own conditions are spelled with its table name rather than
    # the association's, because that is how the primitive's scopes spell them
    # and the two have to be chainable: `where(grant: { … })` would alias the
    # join while `merge(Spree::Grant.usable)` keeps the table name, and a query
    # holding both asks for a column that is not in scope.
    scope :for_customer, ->(customer) { joins(:grant).where(spree_grants: { customer_id: customer&.id }) }
    scope :for_store, ->(store) { joins(:grant).where(spree_grants: { store_id: store&.id }) }
    scope :for_campaign, ->(campaign) { where(campaign_id: campaign&.id) }
    # Still in time: the primitive's own window, which is what the wallet's
    # "about to lapse" reads.
    scope :usable, -> { joins(:grant).merge(Spree::Grant.usable) }

    # What the wallet's own tabs ask for. All three are read rather than
    # stored: a coupon is spent when its code has been applied and lapsed when
    # its date passes, and no job writes either.
    scope :unused, lambda {
      joins(:coupon_code, :grant).merge(Spree::CouponCode.unused).merge(Spree::Grant.usable)
    }
    scope :used, -> { joins(:coupon_code).merge(Spree::CouponCode.used) }
    scope :expired, lambda {
      joins(:coupon_code, :grant).
        merge(Spree::CouponCode.unused).
        where(spree_grants: { expires_at: ..Time.current })
    }

    # A code that has been applied to an order is spent whatever the grant still
    # says, and a coupon past its date has lapsed whatever its status is. Both
    # are read rather than stored — `Spree::GiftCard`'s pattern.
    #
    # @return [String] what the wallet shows
    def display_status
      return 'used' if coupon_code.state == 'used'
      return 'expired' if expired?
      return 'revoked' if grant.revoked?

      'unused'
    end

    # @return [Boolean] whether the code has been applied to an order
    def used?
      coupon_code.state == 'used'
    end

    # @return [Boolean] whether it has lapsed by its date
    def expired?
      expires_at.present? && expires_at <= Time.current
    end

    # @return [String] the code the customer shows or types at checkout
    def code
      coupon_code.display_code
    end
  end
end
