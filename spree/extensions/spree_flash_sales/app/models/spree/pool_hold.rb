module Spree
  # A reserved quantity against a pool, owned by a record that is not a cart and
  # not an order — which is what the shipped `Spree::StockReservation` cannot be,
  # since it subtracts from the variant's global availability and would make a
  # held pool read as the goods being out of stock.
  #
  # It knows a pool, an owner, a quantity and a deadline, and nothing about what
  # the pool counts: `6.1-group-buying.md` generalises this into core, and the
  # answers it must keep are its owner, its TTL, its invisibility to
  # `Stock::Quantifier` (it owns no `StockLevel` and never consults one) and the
  # backorderable case, which does not arise here because there is no quantifier
  # to consult.
  class PoolHold < Spree.base_class
    STATUSES = %w[holding released].freeze

    belongs_to :pool, class_name: 'Spree::FlashSale::Pool', inverse_of: :holds
    belongs_to :owner, polymorphic: true

    validates :quantity, numericality: { greater_than: 0 }
    validates :status, inclusion: { in: STATUSES }
    validates :expires_at, presence: true

    scope :holding, -> { where(status: 'holding') }
    scope :expired, -> { holding.where(expires_at: ..Time.current) }

    # Takes the units against one pool, or answers nothing when the pool has not
    # got them — the caller decides what to say about that.
    #
    # @param owner [ActiveRecord::Base] what the hold belongs to
    # @param pool [Spree::FlashSale::Pool]
    # @param quantity [Integer]
    # @param expires_at [Time]
    # @return [Spree::PoolHold, nil]
    def self.reserve!(owner:, pool:, quantity:, expires_at:)
      return nil unless pool.reserve!(quantity)

      create!(pool: pool, owner: owner, quantity: quantity, expires_at: expires_at, status: 'holding')
    end

    # Gives the units back. Idempotent on this row's own status, so a sweep that
    # runs twice — or a cancellation racing an expiry — releases once.
    # @return [Boolean] whether this call was the release
    def release!
      return false if released?

      transaction do
        flipped = self.class.where(id: id, status: 'holding').
                  update_all(status: 'released', released_at: Time.current, updated_at: Time.current)
        next false if flipped.zero?

        pool.release!(quantity)
        true
      end
    end

    def released?
      status == 'released'
    end

    # Releases whatever has lapsed. A sweep that does not run delays a release;
    # it never miscounts, because every release is guarded by its own row.
    # @return [Integer] how many holds were released
    def self.sweep_expired!(limit: nil)
      scope = expired
      scope = scope.limit(limit) if limit
      scope.find_each.count(&:release!)
    end
  end
end
