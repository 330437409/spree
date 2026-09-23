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

    validates :to_phone, presence: true
    validates :expires_at, presence: true
    validate :transferable_answers_the_contract
    validate :one_pending_window

    # Windows still open — and the status scope, deliberately: everything a
    # client reads as 赠送中 comes through here, and a pending row past its date
    # is not one anybody may act on. The stored status is still `pending`; the
    # date is what says whether it still means anything.
    scope :open_windows, -> { where(status: 'pending').where(expires_at: Time.current..) }
    scope :pending, -> { open_windows }
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

    # @return [Object] the holding, the card or the membership card
    def thing
      transferable
    end

    private

    def transferable_answers_the_contract
      return if transferable.nil?

      missing = CONTRACT.reject { |method| transferable.respond_to?(method) }
      return if missing.empty?

      errors.add(:transferable, :not_transferable,
                 message: Spree.t('transfers.errors.not_transferable', type: transferable.class.name))
    end

    # The index is the last word; this is the same rule said where a caller can
    # read it, so a second window is a validation failure rather than a raw
    # RecordNotUnique out of the service.
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
