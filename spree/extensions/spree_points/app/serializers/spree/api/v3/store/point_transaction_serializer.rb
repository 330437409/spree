module Spree
  module Api
    module V3
      module Store
        # One movement of a balance: what it was worth, where the balance stood
        # once it was written, and the operator's own label for why.
        #
        # The label is the reason list's, not the client's: a fifth reason is
        # an operator's row rather than a release, and a key the list does not
        # hold yet still reads, as itself.
        class PointTransactionSerializer < BaseSerializer
          typelize kind: :string, label: :string, amount: :string,
                   balance_after: 'string | null', occurred_at: 'string'

          attributes :kind

          attribute(:label) { |entry| Spree::PointReason.label_for(entry.store, entry.kind) }
          # `decimal_string` for both amounts: a decimal column back as
          # BigDecimal renders 50 as "0.5e2".
          attribute(:amount) { |entry| decimal_string(entry.amount) }
          attribute(:balance_after) { |entry| decimal_string(entry.balance_after) }
          attribute(:occurred_at) { |entry| entry.occurred_at&.iso8601 }
        end
      end
    end
  end
end
