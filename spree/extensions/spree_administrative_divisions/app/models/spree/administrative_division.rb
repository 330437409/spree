module Spree
  # One node of the Chinese administrative tree. Reference data: it belongs to
  # no store (like Spree::Country and Spree::State), it is imported rather than
  # edited, and a correction is a new `dataset_version` rather than an update
  # inside one (docs/plans/6.1-administrative-division-gem.md).
  #
  # A division is addressed by its `code` — GB/T 2260 for province, city and
  # district, the statistics bureau's code for a township, `CN` for the
  # national root — because a code survives a re-import and a row id does not.
  class AdministrativeDivision < Spree.base_class
    has_prefix_id :adm

    LEVELS = %w[country province city district township].freeze

    # The code the root carries in the shipped dataset, and therefore the code a
    # resolved path starts at. It is a constant rather than a query because the
    # tree has exactly one root and every reader would otherwise ask for it.
    ROOT_CODE = 'CN'.freeze

    # How many digits of a code name this level, and therefore how many every
    # code below it shares: a province is two, a city four, a district six, a
    # township all nine. That is what makes "this node or anything under it" a
    # single indexed prefix match rather than a walk down the tree.
    PREFIX_LENGTHS = { 'country' => 0, 'province' => 2, 'city' => 4, 'district' => 6, 'township' => 9 }.freeze

    belongs_to :parent, class_name: 'Spree::AdministrativeDivision', optional: true, inverse_of: :children
    has_many :children, class_name: 'Spree::AdministrativeDivision', foreign_key: :parent_id,
                        dependent: :destroy, inverse_of: :parent

    validates :level, presence: true, inclusion: { in: LEVELS }
    validates :depth, :dataset_version, presence: true
    validates :depth, numericality: { greater_than_or_equal_to: 0 }
    validates :code, presence: true, uniqueness: { scope: spree_base_uniqueness_scope }
    validates :name, :first_pinyin, :source, presence: true

    scope :at_level, ->(level) { where(level: level) }

    # @return [String] the digits every node under this one shares, empty at the
    #   root — where every code in the tree matches and the whole country is the
    #   subtree
    def subtree_code_prefix
      code.to_s[0, PREFIX_LENGTHS.fetch(level, 0)].to_s
    end

    CURRENT_DATASET_VERSION_KEY = 'spree_administrative_divisions/dataset_version'.freeze

    # The release the table currently holds. Read through the cache because
    # every cached read keys on it: the tree changes only when the import writes
    # a release, which clears this one key — the entries themselves are keyed by
    # release and simply age out.
    #
    # @return [String, nil]
    def self.current_dataset_version
      Rails.cache.fetch(CURRENT_DATASET_VERSION_KEY) { maximum(:dataset_version) }
    end

    # @return [String] the key the current release is memoised under
    def self.current_dataset_version_key
      CURRENT_DATASET_VERSION_KEY
    end
  end
end
