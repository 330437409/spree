module Spree
  module Api
    module V3
      module Store
        module Customer
          module PointAccounts
            # One balance's history: every movement, newest first, with the
            # client's own filter — 全部 is no filter, 收入 is `income`, 支出 is
            # `revenue`.
            #
            # Both balances read the same shape: the growth value page is a
            # flat list where the points page groups by month, and that
            # difference is the client's rendering rather than the server's
            # answer.
            class TransactionsController < ResourceController
              prepend_before_action :require_authentication!
              before_action :set_account

              protected

              def model_class
                Spree::LedgerEntry
              end

              def serializer_class
                Spree::Api::V3::Store::PointTransactionSerializer
              end

              def scope
                entries = super.for_account(@account)

                case params[:filter].presence
                when 'income' then entries.where(Spree::LedgerEntry.arel_table[:amount].gt(0))
                when 'revenue' then entries.where(Spree::LedgerEntry.arel_table[:amount].lt(0))
                else entries
                end
              end

              # Newest first: a ledger is read from what just happened.
              def apply_collection_sort(collection)
                collection.reorder(occurred_at: :desc, id: :desc)
              end

              private

              # A balance this customer does not hold is not a list with
              # nothing in it — the row does not exist, and that is the 404 the
              # rest of v3 answers with.
              def set_account
                @account = Spree::PointAccount.find_by(store: current_store, customer: current_user,
                                                       kind: params[:kind])
                raise ActiveRecord::RecordNotFound if @account.nil?
              end
            end
          end
        end
      end
    end
  end
end
