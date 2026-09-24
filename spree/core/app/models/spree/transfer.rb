module Spree
  # Something on its way to somebody: one row for a coupon holding, a gift card
  # or a membership card, and the opaque token that carries it.
  #
  # What the three domains share is the *journey* — the token, the window, the
  # three endings, and a recipient who can read it before signing in — while what
  # moves and what happens when it arrives stays the domain's own business,
  # through the contract the thing being moved implements
  # (docs/plans/6.1-transfer-primitive.md).
  #
  # `expired` is a date fact and never a stored status, exactly as it is for a
  # gift card: the column holds `pending`, `accepted` or `canceled`, and
  # #display_status reports the fourth to a reader.
  class Transfer < Spree.base_class
    has_prefix_id :tr

    include Spree::SingleStoreResource
    include Spree::HasStatus

    acts_as_paranoid

    # A gift that is given, claimed or taken back is something a store may want to
    # tell somebody about; what *moves* stays the domain's own business.
    publishes_lifecycle_events

    has_status :pending, :accepted, :canceled, default: :pending

    # What a reader is told: the stored statuses plus `expired`, which no
    # transition writes.
    DISPLAY_STATUSES = (statuses + %w[expired]).freeze

    # What the thing being moved has to answer. A model that answers none of
    # these is not transferable, and this says so by name rather than failing
    # later, when somebody tries to claim it.
    CONTRACT = %i[on_transfer_given on_transfer_accepted on_transfer_canceled].freeze

    has_secure_token :token

    belongs_to :transferable, polymorphic: true
    belongs_to :from_customer, class_name: "::#{Spree.customer_class}"
    # Nil until somebody claims it: the recipient may not have an account yet.
    belongs_to :to_customer, class_name: "::#{Spree.customer_class}", optional: true

    # A window may name who it is for, or be open to whoever holds the token —
    # a voucher shared in a group chat is the second kind, and the token is then
    # the only thing that carries it. What a giver types is a delivery hint
    # rather than a permission: the claim checks the window, never the phone.
    validates :expires_at, presence: true
    validate :expires_at_lies_ahead, on: :create
    validate :transferable_answers_the_contract
    validate :one_pending_window

    # Windows still open — and the status scope, deliberately: everything a
    # client reads as 赠送中 comes through here, and a pending row past its date
    # is not one anybody may act on. The stored status is still `pending`; the
    # date is what says whether it still means anything.
    scope :pending, -> { where(status: 'pending').where(expires_at: Time.current..) }
    # Still `pending` and past its date: dead, but still holding the thing it
    # carries, because the unique index counts rows and cannot be filtered by the
    # clock (`now()` is not immutable, so PostgreSQL refuses it in a predicate).
    # What a new give clears, and what a giver may close by hand.
    scope :pending_but_lapsed, ->(transferable) { where(transferable: transferable, status: 'pending').where(expires_at: ..Time.current) }
    scope :for_recipient, ->(customer) { where(to_customer_id: customer&.id) }
    scope :for_giver, ->(customer) { where(from_customer_id: customer&.id) }
    scope :expiring_before, ->(time) { where(status: 'pending').where(expires_at: ..time) }

    # @return [Boolean] whether its window closed without being answered
    def expired?
      pending? && expires_at.present? && expires_at <= Time.current
    end

    # @return [String] what a reader is told: the stored status, or `expired`
    #   when the window has closed
    def display_status
      (expired? ? :expired : status).to_s
    end

    private

    # A window that opens already closed is a gift nobody can ever claim, and it
    # would hold the thing until somebody cleared it by hand. Read when it opens,
    # not afterwards: a window is expected to outlive its own date, and closing
    # one that has is exactly what 作废 does.
    def expires_at_lies_ahead
      return if expires_at.nil? || expires_at > Time.current

      errors.add(:expires_at, :in_the_past, message: Spree.t('transfers.errors.expires_at_in_the_past'))
    end

    def transferable_answers_the_contract
      return if transferable.nil?

      missing = CONTRACT.reject { |method| transferable.respond_to?(method) }
      return if missing.empty?

      errors.add(:transferable, :not_transferable,
                 message: Spree.t('transfers.errors.not_transferable', type: transferable.class.name))
    end

    # The index is the last word; this is the same rule said where a caller can
    # read it, so a second window is a validation failure rather than a raw
    # RecordNotUnique out of the service. Deliberately the raw status, lapsed rows
    # included, because that is what the index counts: a writer that does not go
    # through `give!` cannot save over a lapsed window either, and this is the
    # error it should hear rather than the database's.
    #
    # The service is what makes a lapsed window not stand in the way — it clears
    # them before writing a new one.
    def one_pending_window
      return if transferable.nil? || !pending?

      waiting = self.class.where(transferable_type: transferable_type, transferable_id: transferable_id,
                                 status: 'pending').where.not(id: id)
      return unless waiting.exists?

      errors.add(:transferable, :already_transferring,
                 message: Spree.t('transfers.errors.already_transferring'))
    end
  end
end
