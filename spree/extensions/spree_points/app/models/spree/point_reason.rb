module Spree
  # Why a balance moved, as a row rather than a constant: the client hardcodes
  # four values and would need a release to show a fifth, so a fifth is an
  # operator action — which is also how the review extension earns without
  # this gem enumerating a reason for it.
  class PointReason < Spree.base_class
    # Read once per request: a page of movements needs one label each, and the
    # list is operator data that changes between deploys rather than between
    # rows.
    #
    # @param store [Spree::Store]
    # @param key [String]
    # @return [String] the operator's label, or the key itself while the list
    #   does not hold it
    def self.label_for(store, key)
      return key.to_s if store.nil? || key.blank?

      labels = RequestStore.store[:point_reason_labels] ||= {}
      labels[store.id] ||= for_store(store).pluck(:key, :label).to_h
      labels[store.id][key.to_s] || key.to_s
    end

    include Spree::SingleStoreResource
    include Spree::Metadata

    validates :key, presence: true, uniqueness: { scope: [:store_id, *spree_base_uniqueness_scope] }
    validates :label, presence: true

    scope :for_kind, ->(kind) { where(balance_kind: [nil, kind.to_s]) }
    scope :ordered, -> { order(:position, :id) }
  end
end
