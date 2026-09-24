module Spree
  # One purchase that is not a shippable order: a membership term, points, a
  # card, a coupon bundle, a place in a group buy.
  #
  # The row carries what the client shows — what kind it is, how much it costs,
  # in which channel it was bought, and where it is — and it is paid through the
  # ordinary payment session, which is why core's payment rows know this shape
  # as an owner. A purchase that genuinely delivers goods is an ordinary order
  # that this row links to instead.
  #
  # Its kinds are registered classes (`SpreeScenarioPurchases.scenario_order_kinds`)
  # answering what they cost, what settling them issues and what refunding them
  # takes back, so a seventh scenario is a class rather than another branch
  # (docs/plans/6.1-scenario-purchases.md).
  class ScenarioOrder < Spree.base_class
    include Spree::SingleStoreResource
    include Spree::HasStatus
    include Spree::Metadata

    publishes_lifecycle_events

    acts_as_paranoid

    has_prefix_id :scn

    has_status :pending, :paying, :paid, :canceled, :expired, default: :pending

    # Null while a purchase was made before there was an account to attach it
    # to, which a claim fills in.
    belongs_to :customer, class_name: Spree.customer_class.to_s, optional: true

    # Set only where the scenario delivers physical goods; what is bought is an
    # ordinary order then, and this row is how the purchase and the shipment
    # find each other.
    belongs_to :order, class_name: 'Spree::Order', optional: true

    has_many :payment_sessions, class_name: 'Spree::PaymentSession', dependent: nil
    has_many :payments, class_name: 'Spree::Payment', dependent: nil

    # The attempt being paid through: a purchase can be attempted more than
    # once, and the client only ever shows the current one. Declared as an
    # association rather than a method so a page of purchases loads its
    # sessions in one query.
    has_one :payment_session, -> { order(created_at: :desc) }, class_name: 'Spree::PaymentSession',
                              dependent: nil

    validates :kind, presence: true
    validates :currency, presence: true
    validates :amount, numericality: { greater_than_or_equal_to: 0 }
    # Checked where the kind is chosen, not on every write: a gem that is
    # uninstalled must not stop an existing purchase from recording that it was
    # paid.
    validate :kind_must_be_registered, on: :create

    # Bought and not settled yet. The sweep turns these into `expired` once
    # their window passes; the window itself is the session's own `expires_at`,
    # which is why `open_now` also excludes them below.
    scope :unsettled, -> { with_status(:pending, :paying) }

    # Past the window its session gave it. Read rather than copied: a purchase
    # that lapsed a minute ago is already here, whether or not the sweep has run.
    scope :lapsed, lambda {
      where(
        id: Spree::PaymentSession.where(expires_at: ..Time.current).where.not(scenario_order_id: nil).
            select(:scenario_order_id)
      )
    }

    # What the unpaid screens ask for: bought, not settled, and not past its
    # window — so what a customer is shown never depends on a job having run.
    scope :open_now, -> { unsettled.where.not(id: lapsed.select(:id)) }

    # One kind's own history, which is how a plan that sells something here
    # reads back what it sold.
    scope :for_kind, ->(kind) { where(kind: kind) }
    scope :for_customer, lambda { |customer|
      # A purchase with no customer is one made before there was an account, and
      # it belongs to whoever later claims it rather than to every guest.
      customer.nil? ? none : where(customer_id: customer.id)
    }

    # @return [Array<Class>] the kinds a purchase may be
    def self.available_kinds
      SpreeScenarioPurchases.scenario_order_kinds
    end

    # Registered by `api_type` rather than through `registers_subclasses_via`,
    # because a kind is not a subclass of this model: it is a plain class the
    # plan that owns the entitlement writes, and what it is registered in is
    # this frame's own list.
    #
    # @param kind [String, Symbol] a kind or its `api_type`
    # @return [Class, nil]
    def self.kind_for(kind)
      available_kinds.find { |candidate| candidate.api_type == kind.to_s }
    end

    # @return [Class, nil] the registered kind this row names
    def kind_class
      self.class.kind_for(kind)
    end

    # The money contract core's payment code reads off whatever it is for —
    # `Spree::Payment` asks an owner for its total, what it has already been
    # paid, and whether store credit covers it, and the gateway asks for a
    # number it can build a merchant order number from.
    #
    # A purchase charges its own amount once and has no store-credit arithmetic:
    # paying with a balance is an order's route, not a purchase's, so a
    # scenario order is never covered by one.

    # @return [BigDecimal]
    def total
      amount
    end

    # @return [BigDecimal]
    def total_minus_store_credits
      amount
    end

    # @return [BigDecimal]
    def payment_total
      payments.completed.sum(:amount)
    end

    # @return [Boolean]
    def covered_by_store_credit?
      false
    end

    # @return [BigDecimal]
    def available_store_credits
      0
    end

    # @return [String]
    def number
      prefixed_id
    end

    # Whether whatever this is for has finished the part core would otherwise
    # drive. A purchase has no checkout to complete: paying for it is the whole
    # of it, so it is complete from the moment it exists. The webhook workflow
    # asks this before it settles a session, and an owner that cannot answer
    # fails the settlement it was called for.
    #
    # @return [Boolean]
    def completed?
      true
    end

    # A settled purchase stays in the customer's history: what was bought has
    # been handed over, and the row is the record of it.
    #
    # @return [Boolean]
    def can_be_deleted?
      !paid?
    end

    # Called by core after a payment of this owner is destroyed. A purchase
    # computes what it has been paid from its own payment rows rather than
    # caching a total, so there is nothing to refresh.
    #
    # @return [void]
    def refresh_payment_total!
      payment_total
    end

    private

    def kind_must_be_registered
      return if self.class.kind_for(kind).present?

      errors.add(:kind, :not_a_registered_scenario_order,
                 message: Spree.t('errors.messages.not_a_registered_scenario_order'))
    end
  end
end
