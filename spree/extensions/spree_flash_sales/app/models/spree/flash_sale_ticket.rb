module Spree
  # A customer's claim on an activity's units: the client's ticket.
  #
  # It holds pool units while unpaid — which is why the client can say 前面还有
  # {{standbyTicket}} 人未支付 — and it holds no price: the price is settled where
  # the client settles it, so a ticket claimed yesterday cannot carry yesterday's
  # price into a payment made today. It is not a cart and not an order, and the
  # goods' own stock never sees it.
  class FlashSaleTicket < Spree.base_class
    has_prefix_id :ftick

    STATUSES = %w[holding settled expired replaced canceled].freeze

    # The client's own window — 请在5分钟内完成支付 — and a default rather than a
    # promise: an activity may name its own.
    DEFAULT_TTL = 5.minutes

    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :flash_sale, class_name: 'Spree::FlashSale', inverse_of: :tickets
    belongs_to :flash_sale_slot, class_name: 'Spree::FlashSale::Slot', optional: true, inverse_of: :tickets
    belongs_to :variant, class_name: 'Spree::Variant'
    belongs_to :customer, class_name: "::#{Spree.customer_class}"
    has_many :holds, class_name: 'Spree::PoolHold', as: :owner, dependent: :destroy

    validates :quantity, numericality: { greater_than: 0 }
    validates :status, inclusion: { in: STATUSES }
    validates :active_key, uniqueness: { allow_nil: true }

    before_validation :stamp_active_key

    scope :holding, -> { where(status: 'holding') }
    scope :unpaid, -> { holding.order(:expires_at) }
    scope :lapsed, -> { holding.where(expires_at: ..Time.current) }
    scope :lapsed_for, ->(flash_sale) { lapsed.where(flash_sale: flash_sale) }

    def holding?
      status == 'holding'
    end

    # Gives the units back and ends the claim. The replacement path calls this
    # inside the transaction that grants the new ticket, so a customer cannot
    # hold the same units twice by re-claiming.
    #
    # Idempotence is decided by the row rather than by the instance in hand: a
    # release that already happened, or one whose transaction rolled back,
    # leaves this object's own status saying otherwise, and a caller that then
    # replaced it twice would hold the units twice.
    #
    # @param reason [String] replaced, expired, canceled or settled
    # @return [Boolean] whether this call was the one that released
    def release!(reason: 'expired')
      transaction do
        flipped = self.class.where(id: id, status: 'holding').
                  update_all(status: reason, active_key: nil, updated_at: Time.current)
        next false if flipped.zero?

        reload
        holds.each(&:release!)
        true
      end
    end

    def expired?(now: Time.current)
      holding? && expires_at <= now
    end

    # Releases every claim whose payment window has closed.
    #
    # The ticket is what expires, not the hold: a hold released on its own would
    # give the units back while the ticket still said it held them, so the next
    # customer could take the same units and the customer who lapsed would stay
    # blocked by a claim nobody cleared.
    #
    # @param scope [ActiveRecord::Relation, nil] narrows the sweep, which is how
    #   a claim clears its own activity before counting what is held
    # @return [Integer] how many claims were released
    def self.release_lapsed!(scope = lapsed)
      scope.find_each.count(&:release_expired!)
    end

    # @return [Boolean] whether this call was the one that released
    def release_expired!(now: Time.current)
      release!(reason: 'expired') if expired?(now: now)
    end

    private

    # One live ticket per customer per activity, enforced by a unique index over
    # this column: it is set while the ticket holds and cleared the moment it
    # does not, so the index never sees two live claims.
    def stamp_active_key
      self.active_key = holding? ? "#{customer_id}:#{flash_sale_id}" : nil
    end
  end
end
