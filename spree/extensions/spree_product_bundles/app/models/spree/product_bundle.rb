module Spree
  # A composition and a discount: which variants, in what quantity, form a set,
  # and what the set costs.
  #
  # It is deliberately not sellable — no price column, no stock, no weight, no
  # shipment, no reviews. The components are ordinary variants and carry every
  # one of those, which is what the client's own exploded wire proves a combo
  # does not have: adding one writes one cart line per component
  # (docs/plans/6.1-product-bundles.md).
  class ProductBundle < Spree.base_class
    include Spree::SingleStoreResource
    include Spree::Metadata
    include Spree::HasListPosition

    acts_as_paranoid
    publishes_lifecycle_events

    has_prefix_id :bundle

    acts_as_list scope: :store_id

    include Spree::HasStatus

    has_status :draft, :active, :archived, default: :draft

    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :seller, class_name: 'Spree::Seller', optional: true
    has_many :components, class_name: 'Spree::BundleComponent', dependent: :destroy, inverse_of: :bundle
    has_many :variants, through: :components, source: :variant
    has_many :bundle_line_items, class_name: 'Spree::BundleLineItem', dependent: :destroy, inverse_of: :bundle
    has_many :line_items, through: :bundle_line_items

    # The saving, as a rule rather than a number: a component's price moving
    # upstream has to move the bundle's price with it, and storing the rule is
    # what keeps that visible instead of leaving a stale figure behind.
    preference :discount_kind, :string, default: 'amount'
    preference :discount_value, :decimal, default: 0

    DISCOUNT_KINDS = %w[amount percentage].freeze

    before_validation :normalize_slug, if: -> { slug.blank? && title.present? }
    before_validation :adopt_component_seller, if: -> { seller_id.nil? && components.any? }

    validates :title, :slug, presence: true
    validates :slug, uniqueness: { scope: spree_base_uniqueness_scope, case_sensitive: false }
    validates :preferred_discount_kind, inclusion: { in: DISCOUNT_KINDS }
    validates :preferred_discount_value, numericality: { greater_than_or_equal_to: 0 }
    validate :components_share_one_seller, if: -> { components.any? }
    validate :components_are_distinct, if: -> { components.any? }

    scope :for_seller, ->(seller) { where(seller_id: seller.respond_to?(:id) ? seller.id : seller) }

    # The bundles a goods belongs to — one of the client's four calls, answered
    # as a filter rather than as its own read. A prefixed id is accepted so a
    # request can filter without resolving the variant first.
    scope :with_component_variant, lambda { |variant_or_id|
      variant_id = if variant_or_id.is_a?(String)
                     Spree::Variant.decode_own_prefixed_id(variant_or_id)
                   else
                     variant_or_id&.id
                   end

      joins(:components).where(Spree::BundleComponent.table_name => { variant_id: variant_id })
    }

    # The bundles the menu's combo zone lists: those whose components include a
    # product in the category or in one of its descendants, which is the rule
    # the products read applies.
    scope :in_category, lambda { |category_or_id|
      category = if category_or_id.is_a?(String)
                   Spree::Category.find_by_prefix_id(category_or_id)
                 else
                   category_or_id
                 end
      next none if category.nil?

      joins(variants: :product).
        where(Spree::Product.table_name => { id: Spree::Product.in_taxon(category).select(:id) })
    }

    # The seller axis a read resolves from the request, not a column a client
    # filters by: a seller who is not selling today takes their bundles with
    # them, and the operator's own bundles belong to no seller at all.
    scope :sellable, lambda {
      bundles = arel_table
      where(bundles[:seller_id].eq(nil).or(bundles[:seller_id].in(Spree::Seller.sellable.select(:id))))
    }

    scope :available, -> { active.sellable }

    self.whitelisted_ransackable_attributes = %w[status seller_id position]
    self.whitelisted_ransackable_scopes = %w[with_component_variant in_category]

    # What the components cost bought one by one — the figure the client shows
    # struck through beside the bundle's own price.
    # @param currency [String, nil] defaults to the request's own
    # @return [BigDecimal]
    def goods_price(currency = nil)
      components.sum { |component| component.goods_amount(currency) }
    end

    # What the set costs: the components' own sum less the saving.
    # @return [BigDecimal]
    def price
      [goods_price - saving, 0].max
    end

    # The saving itself, from whichever rule the merchant set. It can never be
    # more than the components cost, so a bundle cannot be priced below zero.
    # @return [BigDecimal]
    def saving
      amount = if preferred_discount_kind == 'percentage'
                 goods_price * preferred_discount_value.to_d / 100
               else
                 preferred_discount_value.to_d
               end

      [amount, goods_price].min
    end

    # How many of this bundle the shelf can fill: the scarcest component,
    # expressed in bundles rather than in units, which is the number the client
    # compares a combo quantity against. Since a bundle has no stock of its
    # own, this is arithmetic over the components' own availability and nothing
    # more — core's quantifier already subtracts reservations and honours
    # backorders.
    #
    # @param stock_location [Spree::StockLocation, nil] defaults to the
    #   seller's own warehouse; nil asks the store's whole network
    # @return [Integer]
    def available_bundles(stock_location: nil)
      return 0 if components.empty?

      location = stock_location || default_stock_location
      components.map { |component| component.available_units(stock_location: location) / component.quantity }.min
    end

    # The warehouse a marketplace bundle ships from: the seller's own. A store
    # with no sellers asks the store's whole network instead, which is what a
    # nil location means to the quantifier.
    # @return [Spree::StockLocation, nil]
    def default_stock_location
      return nil if seller.nil?

      seller.stock_locations.active.first
    end

    private

    # A Chinese title parameterizes to its digits and nothing else — 套餐 1
    # becomes "1" — so a title with anything non-ASCII keeps its own text, which
    # is a handle a merchant can read. Everything else takes the usual one, and
    # a title with no words at all falls back to a generated slug.
    def normalize_slug
      suggestion = title.to_s.match?(/[^\x00-\x7F]/) ? title.to_s.strip : title.to_s.parameterize

      self.slug = suggestion.presence || SecureRandom.uuid
    end

    # A bundle with no seller of its own is its components' seller: the offer on
    # a variant is where a marketplace records who sells it, and a variant on an
    # owned product answers its product's seller.
    def adopt_component_seller
      sellers = component_seller_ids
      self.seller_id = sellers.first if sellers.size == 1 && sellers.first.present?
    end

    # @return [Array<Integer, nil>] one entry per component
    def component_seller_ids
      components.map { |component| component.variant&.resolved_seller_id }.uniq
    end

    # A set holds each goods once: two rows for one variant is a composition
    # mistake a merchant makes by adding the same search result twice, and the
    # database's own uniqueness index only catches it on save.
    def components_are_distinct
      variant_ids = components.map(&:variant_id)
      return if variant_ids.size == variant_ids.uniq.size

      errors.add(:components, Spree.t('product_bundles.errors.duplicate_component'))
    end

    # One seller per bundle: the marketplace's split re-totals each child order
    # from its own lines, and a bundle's single price has no home in that
    # fan-out (docs/plans/6.0-multi-vendor-marketplace.md) — refused here
    # rather than made to work there.
    def components_share_one_seller
      sellers = component_seller_ids
      return if sellers.size == 1 && (seller_id.nil? || sellers.first == seller_id)

      errors.add(:components, Spree.t('product_bundles.errors.cross_seller'))
    end
  end
end
