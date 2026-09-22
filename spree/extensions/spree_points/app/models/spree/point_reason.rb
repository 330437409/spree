module Spree
  # Why a balance moved, as a row rather than a constant: the client hardcodes
  # four values and would need a release to show a fifth, so a fifth is an
  # operator action — which is also how the review extension earns without
  # this gem enumerating a reason for it.
  class PointReason < Spree.base_class
    include Spree::SingleStoreResource

    validates :key, presence: true
    validates_store_uniqueness :key
    validates :label, presence: true

    scope :ordered, -> { order(:position, :id) }

    # The key a movement is written under: a reason in hand, or the string a
    # producer passed. The rule lives here so both services read it once.
    #
    # @param reason [String, Spree::PointReason]
    # @return [String]
    def self.key_for(reason)
      reason.respond_to?(:key) ? reason.key : reason.to_s
    end

    # The label a page of movements shows, read once for the page rather than
    # once per row — the list is operator data that changes between deploys
    # rather than between rows.
    #
    # @param store [Spree::Store]
    # @param key [String]
    # @return [String] the operator's label, or the key itself while the list
    #   does not hold it
    def self.label_for(store, key)
      return key.to_s if store.nil? || key.blank?

      labels = Rails.cache.fetch("spree_points/reason_labels/#{store.id}", expires_in: 1.minute) do
        for_store(store).pluck(:key, :label).to_h
      end

      labels[key.to_s] || key.to_s
    end
  end
end
