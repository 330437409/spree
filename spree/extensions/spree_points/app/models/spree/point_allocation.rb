module Spree
  # Which lots a debit drew from: the audit trail, and what a reversal walks
  # back. It is deliberately not the reason `remaining` is knowable — the lot
  # keeps that figure, and only the ledger service writes it.
  class PointAllocation < Spree.base_class
    belongs_to :ledger_entry, class_name: 'Spree::LedgerEntry'
    belongs_to :point_grant, class_name: 'Spree::PointGrant', inverse_of: :point_allocations

    validates :amount, numericality: { only_integer: true, greater_than: 0 }
  end
end
