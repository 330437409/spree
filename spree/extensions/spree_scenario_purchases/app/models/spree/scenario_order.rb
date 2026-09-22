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

    validates :kind, presence: true
    validates :currency, presence: true
    validates :amount, numericality: { greater_than_or_equal_to: 0 }
    validate :kind_must_be_registered

    # What the unpaid screens ask for: bought, not settled yet.
    scope :open_now, -> { with_status(:pending, :paying) }
    scope :for_customer, ->(customer) { where(customer_id: customer&.id) }

    # @return [Array<Class>] the kinds a purchase may be
    def self.available_kinds
      SpreeScenarioPurchases.scenario_order_kinds
    end

    # @param kind [String, Symbol, Class] a kind, its `api_type`, or its class
    # @return [Class, nil]
    def self.kind_for(kind)
      return kind if kind.is_a?(Class)

      available_kinds.find { |candidate| candidate.api_type == kind.to_s }
    end

    # @return [Class, nil] the registered kind this row names
    def kind_class
      self.class.kind_for(kind)
    end

    # @return [Spree::PaymentSession, nil] the session this purchase is paid
    #   through, whichever attempt is the current one
    def payment_session
      payment_sessions.order(created_at: :desc).first
    end

    # What the WeChat gateway asks of whatever a session is for: the amount it
    # charges, the currency, the customer, and a number it can build a merchant
    # order number from.
    #
    # @return [BigDecimal]
    def total_minus_store_credits
      amount
    end

    # @return [String]
    def number
      prefixed_id
    end

    private

    def kind_must_be_registered
      return if self.class.kind_for(kind).present?

      errors.add(:kind, :not_a_registered_scenario_order,
                 message: Spree.t('errors.messages.not_a_registered_scenario_order'))
    end
  end
end
