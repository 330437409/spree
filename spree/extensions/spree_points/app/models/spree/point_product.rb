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

    # Who a good may be offered to. `vip_user` is a member — a condition the
    # membership plan answers for — and `we_chat_user` a customer the platform
    # can subscribe to.
    LIMIT_USER_TYPES = %w[vip_user we_chat_user].freeze

    belongs_to :seller, class_name: 'Spree::Seller', optional: true

    registers_subclasses_via { SpreePoints.point_product_types }

    validates :name, presence: true
    validates :points, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :money, numericality: { greater_than_or_equal_to: 0 }
    validates :stock, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :limit_user_type, inclusion: { in: LIMIT_USER_TYPES }, allow_nil: true
    validate :type_must_be_registered

    scope :ordered, -> { order(:position, :id) }
    scope :featured, -> { where(featured: true) }
    scope :for_category, ->(category) { where(category: category) }
    # A store-wide good and one a seller offers on its own shelf.
    scope :for_seller, ->(seller) { where(seller_id: [nil, seller&.id]) }

    # @return [Boolean] whether a redemption can issue one right now
    def in_stock?
      stock.positive?
    end

    private

    # A subclass is registered by being one; a row written with a class name no
    # registry holds is the case this catches.
    def type_must_be_registered
      return if self.class.find_by_api_type(self.class.api_type).present?

      errors.add(:type, :not_a_registered_point_product,
                 message: Spree.t('errors.messages.not_a_registered_point_product'))
    end
  end
end
