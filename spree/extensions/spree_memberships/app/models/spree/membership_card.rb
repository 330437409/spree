module Spree
  # A membership bought, granted, held or given away — the instrument, before
  # anybody is entitled to anything.
  #
  # The buyer stays the buyer when the card is claimed: a card given away stays
  # in the giver's record as 已赠送 while the entitlement goes to whoever claimed
  # it, which is why the buyer and the activator are two columns and the term
  # hangs off the card rather than owning it
  # (docs/plans/6.1-membership-tiers-and-rights.md).
  #
  # Its status is the card's own — `dormant`, `active`, `recycled`, `expired` —
  # and what moves it is a workflow, never a state machine.
  class MembershipCard < Spree.base_class
    has_prefix_id :mcard

    include Spree::Metadata
    include Spree::SingleStoreResource
    include Spree::HasStatus

    has_status :dormant, :active, :recycled, :expired, default: :dormant

    SOURCES = %w[purchase grant].freeze

    belongs_to :customer, class_name: "::#{Spree.customer_class}"
    belongs_to :customer_group, class_name: 'Spree::CustomerGroup'
    # The tier it grants: one row keyed to the group, and a read rather than a
    # method so a collection can preload it.
    belongs_to :tier_setting, class_name: 'Spree::MembershipTierSetting',
               primary_key: :customer_group_id, foreign_key: :customer_group_id, inverse_of: nil, optional: true
    # The purchase that produced it; nil for a card an operator granted.
    belongs_to :scenario_order, class_name: 'Spree::ScenarioOrder', optional: true
    # The term it started, once it is activated. The card carries the link —
    # a column pointing back at it would be a cycle the two ends could disagree
    # about.
    belongs_to :membership, class_name: 'Spree::Membership', optional: true
    # Who activated it, when that is somebody other than the buyer: a claimed
    # gift is the case this exists for.
    belongs_to :activated_by_customer, class_name: "::#{Spree.customer_class}", optional: true

    validates :source, presence: true, inclusion: { in: SOURCES }
    validate :group_in_same_store

    scope :for_customer, ->(customer) { where(customer_id: customer&.id) }
    # What the wallet counts, and what 相赠 may act on.
    scope :giftable, -> { with_status(:dormant).where(giftable: true) }
    # Cards whose deadline to activate has passed. Read by the sweep.
    scope :overdue, -> { with_status(:dormant).where(activates_before: ..Time.current) }

    # The window this card is inside, if any: what the client reads as 赠送中 —
    # and as 已过期 once its date has passed — and what 作废 closes. An association
    # rather than a query so a wallet can preload it.
    #
    # Deliberately the raw status, like the index the primitive holds: a lapsed
    # window is still the card's window, and hiding it would take the id 作废 needs
    # away from the client. Whether anybody may still act on it is
    # `Spree::Transfers.open?`'s answer, not this one's.
    has_one :pending_transfer, -> { with_status(:pending) }, class_name: 'Spree::Transfer',
            as: :transferable, inverse_of: :transferable

    #
    # The transfer contract (docs/plans/6.1-transfer-primitive.md). The card
    # answers all three, which is what makes it transferable at all.
    #

    # Nothing to reserve: a dormant card is not spendable, so handing one over
    # only opens a window — the card stays exactly where it is until somebody
    # claims it, and 赠送中 comes from the transfer rather than from this row.
    #
    # Refused by the wallet's own definition, which is what the client's 相赠
    # acts on: a card that is not dormant and giftable is not on offer.
    #
    # @raise [Spree::Transfers::Refused] when the card may not be given away
    def on_transfer_given(_transfer)
      return if dormant? && giftable?

      raise Spree::Transfers::Refused, Spree.t('memberships.errors.card_not_giftable')
    end

    # The claim *is* the activation: the card leaves `dormant` for whoever claimed
    # it, and the term it starts is theirs. A refusal — a card past its deadline —
    # travels back and takes the claim with it.
    def on_transfer_accepted(transfer)
      result = Spree::MembershipCards::Activate.call(card: self, customer: transfer.to_customer)
      raise Spree::Transfers::Refused, result.error if result.failure?
    end

    # Back to 待激活 for the giver. Nothing was reserved, so there is nothing to
    # release: the card is theirs again the moment the transfer is not.
    def on_transfer_canceled(_transfer); end

    # @return [Boolean] whether the deadline to activate it has passed
    def overdue?
      dormant? && activates_before.present? && activates_before <= Time.current
    end

    private

    def group_in_same_store
      return if customer_group.nil? || store_id.nil?
      return if customer_group.store_id == store_id

      errors.add(:customer_group, :invalid)
    end
  end
end
