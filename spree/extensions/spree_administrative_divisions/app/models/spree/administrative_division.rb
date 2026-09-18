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

    belongs_to :parent, class_name: 'Spree::AdministrativeDivision', optional: true, inverse_of: :children
    has_many :children, class_name: 'Spree::AdministrativeDivision', foreign_key: :parent_id,
                        dependent: :destroy, inverse_of: :parent

    validates :level, presence: true, inclusion: { in: LEVELS }
    validates :depth, :dataset_version, presence: true
    validates :depth, numericality: { greater_than_or_equal_to: 0 }
    validates :code, presence: true, uniqueness: { scope: spree_base_uniqueness_scope }
    validates :name, :first_pinyin, :source, presence: true

    scope :at_level, ->(level) { where(level: level) }
  end
end
