module Spree
  # A good in the points shop: what it costs and what redeeming it issues.
  #
  # The row declares the thing; the plan that owns it issues it. Its kinds are
  # registered subclasses rather than a validated string, so a kind is a class
  # and a picker reads the registry
  # (docs/plans/6.1-points-and-growth-value.md).
  class PointProduct < Spree.base_class
    include Spree::SingleStoreResource
    include Spree::Metadata

    publishes_lifecycle_events

    acts_as_paranoid

    has_prefix_id :ptgood

    # Who a good may be offered to: the plan's own fixed pair, not a registry —
    # `vip_user` is a member, which the membership plan answers for, and
    # `we_chat_user` a customer the platform can subscribe to.
    LIMIT_USER_TYPES = %w[vip_user we_chat_user].freeze

    # The payload column a kind declares, and the ones it must leave blank.
    # `Spree::CommissionLine` states the shape: concrete keys, exactly one.
    class_attribute :payload_column, instance_writer: false
    self.payload_column = nil

    belongs_to :seller, class_name: 'Spree::Seller', optional: true

    registers_subclasses_via { SpreePoints.point_product_types }

    validates :name, presence: true
    validates :points, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :money, numericality: { greater_than_or_equal_to: 0 }
    validates :stock, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :limit_user_type, inclusion: { in: LIMIT_USER_TYPES }, allow_nil: true
    validate :type_must_be_registered

    scope :featured, -> { where(featured: true) }
    scope :for_category, ->(category) { where(category: category) }
    # `for_seller` means one seller's own rows everywhere in this repository,
    # so this family uses the same words for the same things: `first_party` is
    # the store's own, and the union is what a shelf shows.
    scope :first_party, -> { where(seller_id: nil) }
    scope :for_seller, ->(seller) { where(seller_id: seller.respond_to?(:id) ? seller.id : seller) }
    scope :available_to_seller, ->(seller) { first_party.or(for_seller(seller)) }

    # The kinds a payload may name, and their classes.
    #
    # @return [Array<Class>]
    def self.available_types
      SpreePoints.point_product_types
    end

    # @return [Array<Symbol>] every concrete key a kind may carry, read off the
    #   family so a kind registered later is covered without touching this
    def self.payload_columns
      available_types.filter_map(&:payload_column)
    end

    # @return [Boolean] whether a redemption can issue one right now
    def in_stock?
      stock.positive?
    end

    # Sets the one payload column this kind carries, and requires it.
    #
    # @param column [Symbol]
    # @return [void]
    def self.issues(column)
      self.payload_column = column
      validates column, presence: true
      validate :only_its_own_payload
    end

    private

    # The column holds a class name, and the registry is what says whether it
    # is one of ours — the loaded class is the subclass either way, so only the
    # column can catch a row naming a kind no registry holds
    # (`Spree::CommissionRule` reads it the same way).
    def type_must_be_registered
      return if self.class.available_types.any? { |kind| kind.to_s == type }

      errors.add(:type, :not_a_registered_point_product,
                 message: Spree.t('errors.messages.not_a_registered_point_product'))
    end

    def only_its_own_payload
      mine = self.class.payload_column
      return if mine.nil?

      others = self.class.payload_columns.excluding(mine).select { |key| self[key].present? }
      return if others.empty?

      errors.add(:base, :exactly_one_point_product_payload,
                 message: Spree.t('errors.messages.exactly_one_point_product_payload'))
    end

  end
end
